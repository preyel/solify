#if DEBUG
import Foundation

/// Developer check: runs the reminder rules against made-up weather days and prints PASS/FAIL.
/// Only runs when the app is launched with `-runScenarios` (never in normal use).
enum DebugScenarios {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-runScenarios") else { return }
        run()
        exit(0)
    }

    private static var passed = 0
    private static var failed = 0

    private static func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        if ok { passed += 1 } else { failed += 1 }
        print("\(ok ? "PASS" : "FAIL")  \(name)\(ok ? "" : "  →  \(detail())")")
    }

    // Tomorrow, so every time is in the future.
    private static let calendar = Calendar.current
    private static let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!)
    private static func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    private static var weekday: Int { calendar.component(.weekday, from: day) }

    /// A made-up day: UV and weather for each hour (anything not listed is UV 0, clear, 25°C).
    private static func forecast(
        uv: [Int: Double], temp: [Int: Double] = [:], code: [Int: Int] = [:], rain: [Int: Int] = [:],
        sunset: (Int, Int) = (17, 40)
    ) -> UVForecast {
        let hours = (0..<24).map { h in
            UVForecast.Hour(time: at(h), uv: uv[h] ?? 0, temperature: temp[h] ?? 25, weatherCode: code[h] ?? 0, rainChance: rain[h] ?? 0)
        }
        let dayInfo = UVForecast.Day(
            date: day, maxUV: uv.values.max() ?? 0, sunrise: at(6, 50), sunset: at(sunset.0, sunset.1),
            weatherCode: code.values.max() ?? 0, rainChance: rain.values.max() ?? 0, maxTemperature: temp.values.max() ?? 25
        )
        return UVForecast(timeZoneID: TimeZone.current.identifier, hours: hours, days: [dayInfo], fetchedAt: .now)
    }

    private static func routine(_ blocks: [RoutineBlock] = [], bedtime: Int = 22 * 60) -> Routine {
        Routine(wakeMinutes: 7 * 60, bedtimeMinutes: bedtime, blocks: blocks)
    }

    private static func block(_ kind: RoutineBlock.Kind, _ name: String, _ start: (Int, Int), _ end: (Int, Int)) -> RoutineBlock {
        RoutineBlock(kind: kind, name: name, weekdays: [weekday],
                     startMinutes: start.0 * 60 + start.1, endMinutes: end.0 * 60 + end.1)
    }

    private static func time(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? "tomorrow morning"
    }

    private static func run() {
        print("\n===== Solify reminder checks (made-up weather for \(day.formatted(date: .abbreviated, time: .omitted))) =====")
        let midday: [Int: Double] = [8: 2, 9: 3, 10: 5, 11: 6, 12: 7, 13: 7, 14: 6, 15: 4, 16: 2, 17: 1]

        // 1. Normal: moderate UV, mild weather → 2 hours after applying.
        var plan = ReapplyPlanner.plan(appliedAt: at(10), forecast: forecast(uv: midday), routine: routine(), strict: false, pauseDuringActivities: false)
        check("Normal day → reminder 2 hours later (12:00)", plan.change == .none && plan.fireDate == at(12), "\(plan.change) at \(time(plan.fireDate))")

        // 2. Very high UV → 30 minutes earlier.
        let high: [Int: Double] = [9: 4, 10: 6, 11: 9, 12: 10, 13: 10, 14: 8, 15: 5, 16: 3, 17: 1]
        plan = ReapplyPlanner.plan(appliedAt: at(10), forecast: forecast(uv: high), routine: routine(), strict: false, pauseDuringActivities: false)
        check("UV 10 near peak → reminder 30 min early (11:30)", plan.change == .earlierForUV(10) && plan.fireDate == at(11, 30), "\(plan.change) at \(time(plan.fireDate))")

        // 3. Extreme heat → 30 minutes earlier.
        plan = ReapplyPlanner.plan(appliedAt: at(10), forecast: forecast(uv: midday, temp: [12: 40]), routine: routine(), strict: false, pauseDuringActivities: false)
        if case .earlierForHeat = plan.change, plan.fireDate == at(11, 30) {
            check("104°F → reminder 30 min early (11:30)", true)
        } else {
            check("104°F → reminder 30 min early (11:30)", false, "\(plan.change) at \(time(plan.fireDate))")
        }

        // 4. At school when it wears off → waits until school ends.
        plan = ReapplyPlanner.plan(appliedAt: at(10), forecast: forecast(uv: high), routine: routine([block(.school, "School", (11, 0), (15, 0))]), strict: false, pauseDuringActivities: false)
        check("At school at 12:00 → waits until 3:00 PM", plan.change == .afterIndoors("School") && plan.fireDate == at(15), "\(plan.change) at \(time(plan.fireDate))")

        // 5. Near sunset with low UV → tomorrow.
        plan = ReapplyPlanner.plan(appliedAt: at(14), forecast: forecast(uv: midday), routine: routine(), strict: false, pauseDuringActivities: false)
        check("4:00 PM, sunset 5:40, UV 2 → moved to tomorrow", plan.change == .postponedLowUV && plan.fireDate == nil, "\(plan.change) at \(time(plan.fireDate))")

        // 6. Same, but an outdoor activity is going on → still sent.
        plan = ReapplyPlanner.plan(appliedAt: at(14), forecast: forecast(uv: midday), routine: routine([block(.outdoor, "Tennis", (16, 0), (18, 0))]), strict: false, pauseDuringActivities: false)
        check("Same, but Tennis 4–6 PM → still reminds at 4:00", plan.fireDate == at(16), "\(plan.change) at \(time(plan.fireDate))")

        // 7. Strict Protection: low but not zero UV → still sent; zero UV → tomorrow.
        plan = ReapplyPlanner.plan(appliedAt: at(14), forecast: forecast(uv: midday), routine: routine(), strict: true, pauseDuringActivities: false)
        check("Strict Protection, UV 2 left → still reminds at 4:00", plan.fireDate == at(16), "\(plan.change) at \(time(plan.fireDate))")
        let earlyDark: [Int: Double] = [9: 3, 10: 5, 11: 6, 12: 6, 13: 4, 14: 2, 15: 1]
        plan = ReapplyPlanner.plan(appliedAt: at(14), forecast: forecast(uv: earlyDark), routine: routine(), strict: true, pauseDuringActivities: false)
        check("Strict Protection, UV 0 left → moved to tomorrow", plan.change == .postponedNoUV, "\(plan.change) at \(time(plan.fireDate))")

        // 8. Pause During Activities → waits until the activity ends.
        plan = ReapplyPlanner.plan(appliedAt: at(13), forecast: forecast(uv: midday, sunset: (19, 0)), routine: routine([block(.outdoor, "Soccer", (14, 30), (16, 0))]), strict: false, pauseDuringActivities: true)
        check("Pause on, Soccer 2:30–4:00 → waits until 4:00", plan.change == .afterActivity("Soccer") && plan.fireDate == at(16), "\(plan.change) at \(time(plan.fireDate))")
        plan = ReapplyPlanner.plan(appliedAt: at(13), forecast: forecast(uv: midday, sunset: (19, 0)), routine: routine([block(.outdoor, "Soccer", (14, 30), (16, 0))]), strict: false, pauseDuringActivities: false)
        check("Pause off, same Soccer → reminds during it at 3:00", plan.fireDate == at(15), "\(plan.change) at \(time(plan.fireDate))")

        // 9. Past bedtime → tomorrow.
        plan = ReapplyPlanner.plan(appliedAt: at(20), forecast: forecast(uv: midday), routine: routine(bedtime: 21 * 60), strict: false, pauseDuringActivities: false)
        check("Would go off after 9 PM bedtime → moved to tomorrow", plan.change == .postponedBedtime, "\(plan.change) at \(time(plan.fireDate))")

        // Weather alerts.
        func alerts(_ f: UVForecast, water: WaterResistance = .none) -> [WeatherUpdate.Kind] {
            WeatherAlerts.alerts(on: day, forecast: f, routine: routine(), placeName: "Chandler, AZ",
                                 protectedUntil: nil, waterResistance: water).map(\.update.kind)
        }
        check("Clouds clear at 11 AM with UV 7 → “Skies just cleared”",
              alerts(forecast(uv: midday, code: [8: 3, 9: 3, 10: 3, 11: 0])).contains(.skiesCleared), "\(alerts(forecast(uv: midday, code: [8: 3, 9: 3, 10: 3, 11: 0])))")
        check("UV climbs to 9 → “UV increased” alert", alerts(forecast(uv: high)).contains(.uvRising), "\(alerts(forecast(uv: high)))")
        check("Hits 104°F → heat alert", alerts(forecast(uv: midday, temp: [14: 40])).contains(.heat), "\(alerts(forecast(uv: midday, temp: [14: 40])))")
        let rainy = forecast(uv: midday, code: [13: 61, 14: 61], rain: [13: 80, 14: 80])
        check("80% rain at 1 PM → rain alert", alerts(rainy).contains(.rain), "\(alerts(rainy))")
        check("Calm day → no weather alerts", alerts(forecast(uv: [10: 4, 11: 5, 12: 5, 13: 4])).isEmpty, "\(alerts(forecast(uv: [10: 4, 11: 5, 12: 5, 13: 4])))")
        let busy = forecast(uv: high, temp: [14: 40], code: [8: 3, 9: 3, 10: 3, 11: 0, 15: 61], rain: [15: 80])
        check("Stormy, hot, high-UV day → no more than 3 alerts", alerts(busy).count <= 3, "\(alerts(busy).count) alerts")

        // Notification wording.
        let rainyMorning = NotificationMessage.morning(
            forecast: DayForecast(peakUV: UVReading(index: 9), condition: .rainy, rainChance: 70, maxTemperature: 38),
            spf: .veryHigh, waterResistance: .none, outdoor: [])
        check("Morning briefing mentions UV 9", rainyMorning.title.contains("9"), rainyMorning.title)
        check("Morning briefing suggests water-resistant sunscreen when rain is likely", rainyMorning.body.contains("water-resistant"), rainyMorning.body)
        check("Morning briefing warns about heat", rainyMorning.body.contains("°"), rainyMorning.body)
        let early = NotificationMessage.reapply(plan: ReapplyPlan(appliedAt: at(10), fireDate: at(11, 30), change: .earlierForUV(10)), uv: UVReading(index: 10), spf: .veryHigh)
        check("Early reminder explains it’s near the UV peak", early.body.contains("peak"), early.body)

        print("===== \(passed) passed, \(failed) failed =====\n")
    }
}
#endif
