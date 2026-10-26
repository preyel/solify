import Foundation

/// When the next "time to reapply" reminder goes off, and why it was moved (if it was).
struct ReapplyPlan: Codable, Equatable {
    enum Change: Codable, Equatable {
        /// Goes off 2 hours after applying, like normal.
        case none
        /// Moved 30 min earlier because UV will be very high (the number is the UV).
        case earlierForUV(Int)
        /// Moved 30 min earlier because it'll be very hot (like "104°F").
        case earlierForHeat(String)
        /// Moved to when school / work / etc. ends (the name of it).
        case afterIndoors(String)
        /// Pause During Activities: moved to when an outdoor activity ends (the name of it).
        case afterActivity(String)
        /// UV stays low for the rest of the day, so no reminder until tomorrow's morning briefing.
        case postponedLowUV
        /// Strict Protection: no UV at all for the rest of the day.
        case postponedNoUV
        /// It would go off after bedtime, so no reminder until tomorrow's morning briefing.
        case postponedBedtime
    }

    let appliedAt: Date
    /// When the reminder goes off, or nil if it was moved to tomorrow morning.
    let fireDate: Date?
    let change: Change

    /// When sunscreen actually wears off (always 2 hours after applying).
    var wearsOffAt: Date { appliedAt.addingTimeInterval(Reminders.reapplyInterval) }

    var isPostponed: Bool { fireDate == nil }

    /// Whether this plan is for sunscreen put on at `date` (saved times can be off by a hair).
    func isFor(appliedAt date: Date) -> Bool {
        abs(appliedAt.timeIntervalSince(date)) < 1
    }

    var movedEarlier: Bool {
        switch change {
        case .earlierForUV, .earlierForHeat: true
        default: false
        }
    }

    /// Short reason, for the Home status card, toasts and notifications.
    var reason: String? {
        switch change {
        case .none:
            nil
        case .earlierForUV(let uv):
            "Moved 30 minutes earlier because UV will reach \(uv) (\(UVReading(index: uv).level.name))."
        case .earlierForHeat(let temperature):
            "Moved 30 minutes earlier because it’ll be \(temperature) and you’ll sweat it off faster."
        case .afterIndoors(let name):
            "Moved to when \(name) ends, since you’ll be indoors until then."
        case .afterActivity(let name):
            "Moved to when \(name) ends, since Pause During Activities is on."
        case .postponedLowUV:
            "It’s close to sunset and UV stays low (3 or below), so your next reminder is tomorrow morning."
        case .postponedNoUV:
            "There’s no more UV today, so your next reminder is tomorrow morning."
        case .postponedBedtime:
            "It would be past your bedtime, so your next reminder is tomorrow morning."
        }
    }

    /// A few words for after the time, like "after School" or "UV peak".
    var shortReason: String? {
        switch change {
        case .none: nil
        case .earlierForUV: "early for UV peak"
        case .earlierForHeat: "early for heat"
        case .afterIndoors(let name), .afterActivity(let name): "after \(name)"
        case .postponedLowUV: "low UV near sunset"
        case .postponedNoUV: "no more UV today"
        case .postponedBedtime: "after bedtime"
        }
    }

    var symbol: String {
        switch change {
        case .none: "alarm.fill"
        case .earlierForUV: "sun.max.fill"
        case .earlierForHeat: "thermometer.sun.fill"
        case .afterIndoors: "figure.walk.departure"
        case .afterActivity: "figure.run"
        case .postponedLowUV, .postponedNoUV: "sun.horizon.fill"
        case .postponedBedtime: "moon.zzz.fill"
        }
    }

    // Saving on the phone.

    static func load() -> ReapplyPlan? {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.reapplyPlan) else { return nil }
        return try? JSONDecoder().decode(ReapplyPlan.self, from: data)
    }

    static func decode(_ data: Data?) -> ReapplyPlan? {
        data.flatMap { try? JSONDecoder().decode(ReapplyPlan.self, from: $0) }
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: StorageKey.reapplyPlan)
    }
}

/// The rules for moving the reapply reminder around the user's day and the weather.
enum ReapplyPlanner {
    /// How much earlier the reminder comes when UV or heat is extreme.
    static let moveUp: TimeInterval = 30 * 60
    /// UV at or above this counts as "near the peak" (Very High).
    static let highUV = 8
    /// °C (95°F). Above this, sweat wears sunscreen off faster.
    static let hotCelsius = 35.0
    /// Within this long before sunset, low UV can push the reminder to tomorrow.
    static let beforeSunset: TimeInterval = 2 * 60 * 60
    /// UV at or below this counts as low enough to skip the rest of the day.
    static let lowUV = 3

    static func plan(
        appliedAt: Date,
        forecast: UVForecast?,
        routine: Routine,
        strict: Bool = UserDefaults.standard.bool(forKey: StorageKey.strictProtection),
        pauseDuringActivities: Bool = UserDefaults.standard.bool(forKey: StorageKey.pauseDuringActivities),
        calendar: Calendar = .current
    ) -> ReapplyPlan {
        let standard = appliedAt.addingTimeInterval(Reminders.reapplyInterval)
        var fireDate = standard
        var change = ReapplyPlan.Change.none

        // 1. Indoors (school, work…) when it wears off: wait until they head out.
        if let stretch = routine.indoorStretch(containing: standard, calendar: calendar) {
            fireDate = stretch.end
            change = .afterIndoors(stretch.block.displayName)
        }
        // 1b. In the middle of an outdoor activity and Pause During Activities is on: wait until it ends.
        //     (If that's near sunset with low UV, step 4 below can then move it to tomorrow.)
        else if pauseDuringActivities, let activity = routine.outdoorActivity(containing: standard, calendar: calendar) {
            fireDate = activity.end
            change = .afterActivity(activity.block.displayName)
        }
        // 2. Outside near the UV peak or in strong heat: come 30 minutes sooner.
        else if routine.isAwake(at: standard, calendar: calendar), let forecast {
            let earlier = standard.addingTimeInterval(-moveUp)
            let canMoveUp = earlier > .now && routine.isAwake(at: earlier, calendar: calendar)
                && !routine.isIndoors(at: earlier)
            if canMoveUp {
                let uvSoon = forecast.uv(at: earlier).map(UVReading.init(uv:))
                if let uvSoon, uvSoon.index >= highUV {
                    fireDate = earlier
                    change = .earlierForUV(uvSoon.index)
                } else if let temperature = forecast.hour(at: standard)?.temperature,
                          temperature >= hotCelsius,
                          (forecast.uv(at: standard) ?? 0) >= 3 {
                    fireDate = earlier
                    change = .earlierForHeat(Temperature.text(celsius: temperature))
                }
            }
        }

        // 3. Asleep by then: skip to tomorrow morning.
        if !routine.isAwake(at: fireDate, calendar: calendar) {
            return ReapplyPlan(appliedAt: appliedAt, fireDate: nil, change: .postponedBedtime)
        }

        // 4. Skip to tomorrow morning only if ALL of these are true:
        //    - it's within 2 hours of sunset (or later),
        //    - UV stays at 3 or below for the rest of the day (0 with Strict Protection,
        //      since UVA rays are around whenever it's light out),
        //    - no outdoor activity in those 2 hours is still going when the reminder fires.
        if let forecast,
           let sunset = forecast.day(containing: fireDate)?.sunset,
           fireDate >= sunset.addingTimeInterval(-beforeSunset),
           let rest = forecast.maxUV(fromTimeToEndOfDay: fireDate),
           UVReading(uv: rest).index <= (strict ? 0 : lowUV) {
            // An outdoor activity in the 2 hours before sunset that's still going when the reminder fires.
            let window = DateInterval(start: sunset.addingTimeInterval(-beforeSunset), end: sunset)
            let hasActivity = routine.outdoorActivities(on: fireDate, calendar: calendar)
                .contains { $0.interval.intersects(window) && $0.interval.end > fireDate }
            if !hasActivity {
                return ReapplyPlan(appliedAt: appliedAt, fireDate: nil, change: strict ? .postponedNoUV : .postponedLowUV)
            }
        }

        return ReapplyPlan(appliedAt: appliedAt, fireDate: fireDate, change: change)
    }
}
