import Foundation
import UserNotifications

/// Records that sunscreen was just put on.
enum SunscreenLog {
    /// Saves the time (which restarts the protection timer) and which sunscreen was used,
    /// works out when to remind them, and schedules it. Doesn't touch the saved default sunscreen.
    @discardableResult
    static func recordApplication(spf: SPFLevel, waterResistance: WaterResistance, at date: Date = .now) -> ReapplyPlan {
        let defaults = UserDefaults.standard
        defaults.set(date.timeIntervalSince1970, forKey: StorageKey.lastAppliedAt)
        defaults.set(spf.rawValue, forKey: StorageKey.appliedSPF)
        defaults.set(waterResistance.rawValue, forKey: StorageKey.appliedWaterResistance)

        let plan = ReapplyPlanner.plan(appliedAt: date, forecast: WeatherStore.shared.forecast, routine: .current)
        plan.save()
        Task { await Reminders.refreshAll() }
        return plan
    }
}

/// Schedules all of Solify's notifications:
/// - a morning briefing at wake-up (UV, rain, today's outdoor plans)
/// - the reapply reminder, moved around the user's routine and the weather
/// - a heads-up before each outdoor activity
/// - weather alerts (UV jumping, skies clearing, heat, rain)
///
/// iPhone apps can't watch the weather nonstop, so everything is lined up ahead of time from the
/// forecast and redone whenever the app opens, the forecast updates, or iOS gives the app a
/// moment in the background.
enum Reminders {
    /// How long sunscreen protects before it should be reapplied (2 hours).
    static let reapplyInterval: TimeInterval = 2 * 60 * 60

    /// How many days of morning briefings to line up ahead of time.
    private static let morningDays = 7
    /// How many days of outdoor heads-ups and weather alerts to line up.
    private static let alertDays = 2
    /// Heads-up this long before an outdoor activity starts.
    private static let outdoorLead: TimeInterval = 15 * 60

    private static var center: UNUserNotificationCenter { .current() }
    private static var lastRefresh: Task<Void, Never>?

    enum Reason {
        /// The user did something (applied sunscreen, changed their routine…). They can see the
        /// new plan in the app, so no "your reminder moved" notification.
        case userAction
        /// New weather came in. If that moves the reminder, tell them with a notification.
        case weatherUpdate
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: StorageKey.notificationsEnabled) as? Bool ?? true
    }

    /// Shows Apple's "Allow notifications?" popup (only the first time) and returns whether they're allowed.
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func cancelAll() async {
        await removeScheduled()
    }

    /// Removes everything Solify has lined up (but leaves test notifications alone).
    private static func removeScheduled() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { !$0.hasPrefix("test-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Works everything out again and replaces all scheduled notifications.
    /// Calls are handled one at a time so they can't mix each other up.
    static func refreshAll(reason: Reason = .userAction) async {
        let previous = lastRefresh
        let task = Task {
            await previous?.value
            await performRefresh(reason: reason)
        }
        lastRefresh = task
        await task.value
    }

    private static func performRefresh(reason: Reason) async {
        let defaults = UserDefaults.standard
        let forecast = WeatherStore.shared.forecast
        let placeName = WeatherStore.shared.location?.name ?? "your area"
        let routine = Routine.current
        let calendar = Calendar.current
        let defaultSPF = defaults.string(forKey: StorageKey.spf).flatMap(SPFLevel.init) ?? .veryHigh
        let defaultWater = defaults.string(forKey: StorageKey.waterResistance).flatMap(WaterResistance.init) ?? .minutes80
        let appliedSPF = defaults.string(forKey: StorageKey.appliedSPF).flatMap(SPFLevel.init) ?? defaultSPF

        // The reapply plan (only for sunscreen put on today).
        let lastApplied = defaults.double(forKey: StorageKey.lastAppliedAt)
        let appliedAt = lastApplied > 0 ? Date(timeIntervalSince1970: lastApplied) : nil
        let oldPlan = ReapplyPlan.load()
        var plan: ReapplyPlan?
        if let appliedAt, calendar.isDateInToday(appliedAt) {
            plan = ReapplyPlanner.plan(appliedAt: appliedAt, forecast: forecast, routine: routine)
            // Don't change a reminder that already went off.
            if let oldPlan, oldPlan.isFor(appliedAt: appliedAt), let oldFire = oldPlan.fireDate, oldFire <= .now {
                plan = oldPlan
            }
        }
        plan?.save()
        if plan == nil { defaults.removeObject(forKey: StorageKey.reapplyPlan) }

        await removeScheduled()
        guard isEnabled else { return }

        var requests: [UNNotificationRequest] = []
        func add(_ id: String, _ message: NotificationMessage, at date: Date) {
            guard date > .now else { return }
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            requests.append(UNNotificationRequest(identifier: id, content: message.content, trigger: trigger))
        }

        let morningEnabled = defaults.object(forKey: StorageKey.morningBriefingEnabled) as? Bool ?? true
        let alertsEnabled = defaults.object(forKey: StorageKey.weatherAlertsEnabled) as? Bool ?? true

        // Morning briefings.
        for offset in 0..<(morningEnabled ? morningDays : 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now),
                  let wake = routine.wakeTime(on: day, calendar: calendar)
            else { continue }
            let message = NotificationMessage.morning(
                forecast: Weather.forecast(for: wake),
                spf: defaultSPF,
                waterResistance: defaultWater,
                outdoor: routine.outdoorActivities(on: day, calendar: calendar).map { activity in
                    (name: activity.block.displayName,
                     interval: activity.interval,
                     uv: forecast.flatMap { maxUV(in: activity.interval, forecast: $0) })
                }
            )
            add("morning-\(offset)", message, at: wake)
        }

        // The reapply reminder.
        if let plan, let fireDate = plan.fireDate {
            add("reapply", .reapply(plan: plan, uv: Weather.uv(at: fireDate), spf: appliedSPF), at: fireDate)
        }

        // Tell them if new weather moved their reminder.
        if reason == .weatherUpdate, let oldPlan, let plan, oldPlan.isFor(appliedAt: plan.appliedAt),
           let update = NotificationMessage.reminderMoved(from: oldPlan, to: plan) {
            requests.append(UNNotificationRequest(identifier: "moved-\(UUID())", content: update.content, trigger: nil))
        }

        let protectedUntil = appliedAt.map { $0.addingTimeInterval(reapplyInterval) }
        for offset in 0..<alertDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }

            // Heads-up before outdoor activities (unless sunscreen will still be on).
            for (index, activity) in routine.outdoorActivities(on: day, calendar: calendar).enumerated() {
                let uv = forecast.flatMap { maxUV(in: activity.interval, forecast: $0) }
                // Skip only when it's dark the whole time (UV 0), since sunscreen wouldn't do anything.
                if let uv, uv.index == 0 { continue }
                if let protectedUntil, activity.interval.start < protectedUntil { continue }

                // Normally 15 minutes early, but not while still at school / work:
                // then it comes right when that ends (e.g. school ends 5:00, tennis at 5:00 → 5:00).
                var headsUp = activity.interval.start.addingTimeInterval(-outdoorLead)
                if let stretch = routine.indoorStretch(containing: headsUp, calendar: calendar) {
                    headsUp = min(stretch.end, activity.interval.start)
                }

                // If the reapply reminder is already going off around then, that one covers it.
                if let reapplyAt = plan?.fireDate,
                   reapplyAt >= headsUp.addingTimeInterval(-outdoorLead),
                   reapplyAt <= activity.interval.start {
                    continue
                }

                add("outdoor-\(offset)-\(index)",
                    .outdoorSoon(name: activity.block.displayName, interval: activity.interval, uv: uv, spf: defaultSPF),
                    at: headsUp)
            }

            // Weather alerts.
            if let forecast, alertsEnabled {
                let alerts = WeatherAlerts.alerts(
                    on: day, forecast: forecast, routine: routine, placeName: placeName,
                    protectedUntil: protectedUntil, waterResistance: defaultWater, calendar: calendar
                )
                for (index, alert) in alerts.enumerated() {
                    add("weather-\(offset)-\(index)", NotificationMessage(update: alert.update), at: alert.date)
                }
            }
        }

        // iOS keeps at most 64 waiting notifications; keep the soonest.
        for request in requests.prefix(64) {
            try? await center.add(request)
        }
    }

    private static func maxUV(in interval: DateInterval, forecast: UVForecast) -> UVReading? {
        let uvs = forecast.hours
            .filter { $0.time.addingTimeInterval(3600) > interval.start && $0.time < interval.end }
            .map(\.uv)
        return uvs.max().map(UVReading.init(uv:))
    }

    #if DEBUG
    /// Sends one of each kind of notification, a few seconds apart, for testing.
    /// Uses your real routine, sunscreen and forecast so the wording matches what you'll really get.
    static func sendTestNotifications() async {
        let defaults = UserDefaults.standard
        let spf = defaults.string(forKey: StorageKey.spf).flatMap(SPFLevel.init) ?? .veryHigh
        let water = defaults.string(forKey: StorageKey.waterResistance).flatMap(WaterResistance.init) ?? .minutes80
        let forecast = WeatherStore.shared.forecast
        let place = WeatherStore.shared.location?.name ?? "your area"
        let routine = Routine.current
        let calendar = Calendar.current
        let now = Date.now

        // Your next day with outdoor activities (today if you have one), for the briefing and heads-up.
        let activityDay = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
            .first { !routine.outdoorActivities(on: $0, calendar: calendar).isEmpty } ?? now
        let activities = routine.outdoorActivities(on: activityDay, calendar: calendar).map { activity in
            (name: activity.block.displayName,
             interval: activity.interval,
             uv: forecast.flatMap { maxUV(in: activity.interval, forecast: $0) })
        }

        var messages: [NotificationMessage] = [
            .morning(forecast: Weather.forecast(for: activityDay), spf: spf, waterResistance: water, outdoor: activities),
        ]

        if let first = activities.first {
            messages.append(.outdoorSoon(name: first.name, interval: first.interval, uv: first.uv, spf: spf))
        }

        // Your real reapply reminder if you've applied today, otherwise an "early for UV" example.
        let applied = defaults.double(forKey: StorageKey.lastAppliedAt)
        let appliedSPF = defaults.string(forKey: StorageKey.appliedSPF).flatMap(SPFLevel.init) ?? spf
        if let plan = ReapplyPlan.load(), plan.isFor(appliedAt: Date(timeIntervalSince1970: applied)), let fire = plan.fireDate {
            messages.append(.reapply(plan: plan, uv: Weather.uv(at: fire), spf: appliedSPF))
        } else {
            let example = ReapplyPlan(appliedAt: now.addingTimeInterval(-90 * 60), fireDate: now, change: .earlierForUV(10))
            messages.append(.reapply(plan: example, uv: UVReading(index: 10), spf: spf))
        }

        // A real weather alert from your forecast if there is one coming up, otherwise an example.
        let realAlert = forecast.flatMap { forecast in
            (0..<2).lazy
                .compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
                .flatMap { WeatherAlerts.alerts(on: $0, forecast: forecast, routine: routine, placeName: place,
                                                protectedUntil: nil, waterResistance: water, calendar: calendar) }
                .first
        }
        if let realAlert {
            messages.append(NotificationMessage(update: realAlert.update))
        } else {
            let uv = Weather.uv(at: now) ?? UVReading(index: 9)
            messages.append(NotificationMessage(update: WeatherUpdate(
                kind: .skiesCleared, title: "Skies just cleared.",
                body: "UV is now \(uv.level.name). Apply sunscreen before going outside.",
                headline: "UV is now \(uv.index) (\(uv.level.name))", subtitle: "Skies just cleared up in \(place).",
                why: "Cloud cover has decreased, causing UV levels to rise quickly. (This is a test example.)",
                whatToDo: "Apply sunscreen before spending time outdoors.", uv: uv.index
            )))
        }

        for (index, message) in messages.enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(5 + index * 8), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "test-\(index)", content: message.content, trigger: trigger))
        }
    }
    #endif
}

/// The words in each notification, which change with the UV level, weather and routine.
struct NotificationMessage {
    let title: String
    let body: String
    /// Opens the Weather Update screen when tapped.
    var update: WeatherUpdate? = nil

    init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    init(update: WeatherUpdate) {
        self.title = update.title
        self.body = update.body
        self.update = update
    }

    var content: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let update { content.userInfo = update.userInfo }
        return content
    }

    /// Adds the in-app screen that opens when this notification is tapped.
    private func with(_ update: WeatherUpdate) -> NotificationMessage {
        var message = self
        message.update = update
        return message
    }

    /// The wake-up briefing, like "UV levels will reach 10 (Very High) today."
    static func morning(
        forecast: DayForecast?,
        spf: SPFLevel,
        waterResistance: WaterResistance,
        outdoor: [(name: String, interval: DateInterval, uv: UVReading?)]
    ) -> NotificationMessage {
        let message = morningText(forecast: forecast, spf: spf, waterResistance: waterResistance, outdoor: outdoor)
        let place = WeatherStore.shared.location?.name
        let wake = Routine.timeText(Routine.current.wakeMinutes)

        var details: [String] = []
        if let forecast {
            details.append("UV peaks at \(forecast.peakUV.index) (\(forecast.peakUV.level.name)).")
            if let chance = forecast.rainChance { details.append("\(chance)% chance of rain.") }
            if let temperature = forecast.maxTemperature { details.append("High of \(Temperature.text(celsius: temperature)).") }
        }
        for activity in outdoor {
            let time = activity.interval.start.formatted(date: .omitted, time: .shortened)
            details.append("\(activity.name) at \(time)\(activity.uv.map { ", UV up to \($0.index) (\($0.level.name))" } ?? "").")
        }

        return message.with(WeatherUpdate(
            kind: .morning,
            title: message.title,
            body: message.body,
            headline: forecast.map { "UV will reach \($0.peakUV.index) (\($0.peakUV.level.name)) today" } ?? "Good morning!",
            subtitle: [place, Date.now.formatted(.dateTime.weekday(.wide).month().day())].compactMap { $0 }.joined(separator: " · "),
            why: "This is your daily UV briefing, sent at your wake-up time (\(wake)). " + (details.isEmpty ? "" : details.joined(separator: " ")),
            whatToDo: message.body,
            uv: forecast?.peakUV.index
        ))
    }

    /// The reminder when sunscreen wears off, worded for why it's going off now.
    /// Its screen has an "I've Reapplied" button.
    static func reapply(plan: ReapplyPlan, uv: UVReading?, spf: SPFLevel) -> NotificationMessage {
        let message = reapplyText(plan: plan, uv: uv, spf: spf)
        let applied = plan.appliedAt.formatted(date: .omitted, time: .shortened)
        let why = plan.reason.map { "You put on your \(spf.shortName) at \(applied). \($0)" }
            ?? "You put on your \(spf.shortName) at \(applied). Sunscreen wears off after about 2 hours, from sweat, rubbing and the sun breaking it down."
        return message.with(WeatherUpdate(
            kind: .reapply,
            title: message.title,
            body: message.body,
            headline: message.title,
            subtitle: uv.map { "UV right now: \($0.index) (\($0.level.name))" } ?? "Your protection is wearing off.",
            why: why,
            whatToDo: "Reapply sunscreen to exposed skin, then tap “I’ve Reapplied” to restart your timer.",
            uv: uv?.index,
            action: .reapply
        ))
    }

    /// "Tennis starts at 4:15 PM", sent 15 minutes before an outdoor activity.
    static func outdoorSoon(name: String, interval: DateInterval, uv: UVReading?, spf: SPFLevel) -> NotificationMessage {
        let message = outdoorSoonText(name: name, interval: interval, uv: uv, spf: spf)
        let start = interval.start.formatted(date: .omitted, time: .shortened)
        let end = interval.end.formatted(date: .omitted, time: .shortened)
        return message.with(WeatherUpdate(
            kind: .outdoorSoon,
            title: message.title,
            body: message.body,
            headline: message.title,
            subtitle: "\(start) – \(end)" + (uv.map { " · UV up to \($0.index) (\($0.level.name))" } ?? ""),
            why: "You added \(name) as an outdoor activity in Profile. We send a heads-up 15 minutes before so your sunscreen has time to soak in.",
            whatToDo: message.body,
            uv: uv?.index
        ))
    }

    /// The text of the wake-up briefing.
    private static func morningText(
        forecast: DayForecast?,
        spf: SPFLevel,
        waterResistance: WaterResistance,
        outdoor: [(name: String, interval: DateInterval, uv: UVReading?)]
    ) -> NotificationMessage {
        let sunscreen = spf.shortName
        guard let forecast else {
            return NotificationMessage(title: "Good morning!", body: "Don’t forget to apply your \(sunscreen) before heading outside!")
        }
        let uv = forecast.peakUV
        let level = uv.level

        let title: String
        var body: String
        switch level {
        case .low:
            title = "UV is low today (\(uv.index))"
            body = "Sunscreen is optional, but bring your \(sunscreen) if you’ll be outside for a long time."
        case .moderate, .high, .veryHigh:
            title = "UV levels will reach \(uv.index) (\(level.name)) today"
            body = "Don’t forget to apply your \(sunscreen) before heading outside!"
        case .extreme:
            title = "UV will be extreme today (\(uv.index))"
            body = "Apply your \(sunscreen), wear a hat and sunglasses, and avoid the midday sun."
        }

        // Rain: suggest water-resistant sunscreen.
        if let chance = forecast.rainChance, chance >= 50 {
            body += waterResistance == .none
                ? " There’s a \(chance)% chance of rain, so a water-resistant sunscreen is a good idea today."
                : " There’s a \(chance)% chance of rain. Your water-resistant sunscreen should help."
        } else if forecast.condition == .cloudy, level != .low {
            body = "It’s cloudy, but UV gets through clouds. " + body
        }

        // Heat.
        if let temperature = forecast.maxTemperature, temperature >= WeatherAlerts.heatCelsius {
            body += " It’ll hit \(Temperature.text(celsius: temperature)), so reapply more often if you’re sweating."
        }

        // Today's outdoor plans.
        if let next = outdoor.first(where: { $0.uv.map { $0.index > 0 } ?? true }) {
            let time = next.interval.start.formatted(date: .omitted, time: .shortened)
            if let activityUV = next.uv {
                body += " \(next.name) at \(time): UV up to \(activityUV.index) (\(activityUV.level.name))."
            } else {
                body += " \(next.name) is at \(time)."
            }
        }

        return NotificationMessage(title: title, body: body)
    }

    /// The reminder when sunscreen wears off, worded for why it's going off now.
    private static func reapplyText(plan: ReapplyPlan, uv: UVReading?, spf: SPFLevel) -> NotificationMessage {
        let sunscreen = spf.shortName
        let minutesOn = Int(((plan.fireDate ?? plan.wearsOffAt).timeIntervalSince(plan.appliedAt) / 60).rounded())
        let onFor = minutesOn % 60 == 0 ? "\(minutesOn / 60) hours" : "\(minutesOn) minutes"
        let uvText = uv.map { "UV is \($0.index) (\($0.level.name))" }

        switch plan.change {
        case .earlierForUV:
            return NotificationMessage(
                title: "Reapply now!",
                body: "\(uvText ?? "UV is very high") and your \(sunscreen) has been on for \(onFor). We sent this early because UV is near its peak."
            )
        case .earlierForHeat(let temperature):
            return NotificationMessage(
                title: "Reapply now!",
                body: "It’s \(temperature) and your \(sunscreen) has been on for \(onFor). Sweat wears it off faster in the heat."
            )
        case .afterActivity(let name):
            return NotificationMessage(
                title: "\(name) is over. Time to reapply!",
                body: "Your \(sunscreen) has been on for \(onFor). Reapply now if you’re staying outside\(uvText.map { ". \($0)." } ?? ".")"
            )
        case .afterIndoors(let name):
            return NotificationMessage(
                title: "Heading outside?",
                body: "\(name) is over. Reapply your \(sunscreen) before going out\(uvText.map { ". \($0)." } ?? ".")"
            )
        default:
            guard let uv else {
                return NotificationMessage(title: "It’s time to reapply!", body: "Your \(sunscreen) has been on for \(onFor). Reapply now to stay protected!")
            }
            switch uv.level {
            case .low:
                return NotificationMessage(
                    title: "Time to reapply",
                    body: "Your \(sunscreen) has been on for \(onFor). UV is low right now (\(uv.index)), so reapply if you’re staying outside."
                )
            case .extreme:
                return NotificationMessage(
                    title: "It’s time to reapply!",
                    body: "UV is extreme right now (\(uv.index)) and your \(sunscreen) has been on for \(onFor). Reapply now and stay in the shade if you can."
                )
            default:
                return NotificationMessage(
                    title: "It’s time to reapply!",
                    body: "UV is currently \(uv.index) (\(uv.level.name)) and your \(sunscreen) has been on for \(onFor). Reapply now to stay protected!"
                )
            }
        }
    }

    /// "Soccer starts at 4 PM", sent 15 minutes before an outdoor activity.
    /// Worded for how strong the UV will be: low UV still gets a reminder for long stretches outside.
    private static func outdoorSoonText(name: String, interval: DateInterval, uv: UVReading?, spf: SPFLevel) -> NotificationMessage {
        let time = interval.start.formatted(date: .omitted, time: .shortened)
        let title = "\(name) starts at \(time)"
        let sunscreen = spf.shortName

        let minutes = Int(interval.duration / 60)
        let length = minutes < 60 ? "\(minutes) min"
            : minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"

        guard let uv else {
            return NotificationMessage(title: title, body: "Apply your \(sunscreen) before heading out.")
        }
        switch uv.level {
        case .low:
            return NotificationMessage(
                title: title,
                body: "UV will be low (\(uv.index)), but you’ll be outside for \(length), so sunscreen is still a good idea. Apply your \(sunscreen) before heading out."
            )
        case .moderate, .high:
            return NotificationMessage(
                title: title,
                body: "UV will be up to \(uv.index) (\(uv.level.name)). Apply your \(sunscreen) before heading out."
            )
        case .veryHigh, .extreme:
            return NotificationMessage(
                title: title,
                body: "UV will be up to \(uv.index) (\(uv.level.name)). Apply your \(sunscreen) before heading out, and take breaks in the shade."
            )
        }
    }

    /// "Reminder moved earlier" / "Reminder postponed", sent when new weather changes the plan.
    /// Nil if the change is too small to mention.
    static func reminderMoved(from old: ReapplyPlan, to new: ReapplyPlan) -> NotificationMessage? {
        if old.isPostponed == new.isPostponed {
            guard let oldFire = old.fireDate, let newFire = new.fireDate,
                  abs(newFire.timeIntervalSince(oldFire)) >= 10 * 60
            else { return nil }
        }
        guard let reason = new.reason else { return nil }

        let earlier = new.movedEarlier
        let time = new.fireDate?.formatted(date: .omitted, time: .shortened)
        let title = new.isPostponed ? "Reminder moved to tomorrow" : earlier ? "Reminder moved earlier" : "Reminder moved later"
        let body = new.isPostponed ? reason : "Your next reminder is now at \(time ?? "later"). \(reason)"

        return NotificationMessage(update: WeatherUpdate(
            kind: earlier ? .reminderEarlier : .reminderLater,
            title: title,
            body: body,
            headline: new.isPostponed ? "Next reminder: tomorrow morning" : "Next reminder: \(time ?? "")",
            subtitle: title + ".",
            why: reason,
            whatToDo: new.isPostponed
                ? "No need to reapply tonight. We’ll send your UV briefing when you wake up."
                : earlier ? "Reapply when the reminder comes, and look for shade if you can."
                : "Enjoy your time indoors. We’ll remind you when it’s time to head out."
        ))
    }
}

/// Shows notifications as banners even while the app is open, and opens the
/// Weather Update screen when one is tapped.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    // These use iOS's "completion handler" style and call it back on the main thread.
    // (The async versions call back on a background thread, which crashes the app.)

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler([.banner, .list, .sound])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let json = response.notification.request.content.userInfo[WeatherUpdate.userInfoKey] as? String
        Task { @MainActor in
            if let update = WeatherUpdate.from(json: json) {
                AppRouter.shared.weatherUpdate = update
            }
            completionHandler()
        }
    }
}
