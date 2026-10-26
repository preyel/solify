import Foundation

/// Finds the moments in the forecast worth a heads-up (UV jumping, skies clearing, heat, rain),
/// so they can be scheduled as notifications ahead of time.
enum WeatherAlerts {
    struct Alert {
        let date: Date
        let update: WeatherUpdate
    }

    /// At most this many weather alerts per day, so it doesn't get annoying.
    static let maxPerDay = 3
    /// Alerts are at least this far apart.
    static let minGap: TimeInterval = 90 * 60
    /// °C (100°F).
    static let heatCelsius = 37.8
    /// % chance of rain that counts as "rain is coming".
    static let rainChance = 60

    static func alerts(
        on day: Date,
        forecast: UVForecast,
        routine: Routine,
        placeName: String,
        protectedUntil: Date?,
        waterResistance: WaterResistance,
        calendar: Calendar = .current
    ) -> [Alert] {
        let hours = forecast.hours.filter { calendar.isDate($0.time, inSameDayAs: day) }
        var candidates: [Alert] = []

        /// Only while awake and not stuck at school / work.
        func isGoodTime(_ date: Date) -> Bool {
            date > .now && routine.isAwake(at: date, calendar: calendar) && !routine.isIndoors(at: date)
        }
        func isProtected(at date: Date) -> Bool {
            protectedUntil.map { date < $0 } ?? false
        }

        // Skies clearing up while UV is High or more.
        if let index = hours.indices.dropFirst().first(where: { i in
            let before = hours[i - 1], now = hours[i]
            return (before.weatherCode ?? 0) >= 3 && (now.weatherCode ?? 3) <= 1
                && UVReading(uv: now.uv).index >= 6 && isGoodTime(now.time)
        }) {
            let reading = UVReading(uv: hours[index].uv)
            candidates.append(Alert(date: hours[index].time, update: WeatherUpdate(
                kind: .skiesCleared,
                title: "Skies just cleared.",
                body: "UV is now \(reading.level.name). Apply sunscreen before going outside.",
                headline: "UV is now \(reading.index) (\(reading.level.name))",
                subtitle: "Skies just cleared up in \(placeName).",
                why: "Cloud cover has decreased, causing UV levels to rise quickly.",
                whatToDo: isProtected(at: hours[index].time)
                    ? "You’re still protected, but reapply as soon as your timer runs out."
                    : "Apply sunscreen before spending time outdoors.",
                uv: reading.index
            )))
        }

        // UV first reaching Very High, if they aren't already protected.
        if let index = hours.indices.dropFirst(2).first(where: { i in
            UVReading(uv: hours[i].uv).index >= 8 && UVReading(uv: hours[i - 1].uv).index < 8
                && isGoodTime(hours[i].time) && !isProtected(at: hours[i].time)
        }) {
            let reading = UVReading(uv: hours[index].uv)
            let earlier = UVReading(uv: hours[index - 2].uv)
            candidates.append(Alert(date: hours[index].time, update: WeatherUpdate(
                kind: .uvRising,
                title: "UV increased from \(earlier.level.name) to \(reading.level.name).",
                body: "Consider applying sunscreen before going outside.",
                headline: "UV is now \(reading.index) (\(reading.level.name))",
                subtitle: "UV climbed from \(earlier.index) to \(reading.index) over the last two hours in \(placeName).",
                why: "UV gets stronger as the sun climbs higher. At \(reading.level.name), unprotected skin can burn in under 20 minutes.",
                whatToDo: "Apply sunscreen before going outside, and look for shade around midday.",
                uv: reading.index
            )))
        }

        // Extreme heat.
        if let hour = hours.first(where: { ($0.temperature ?? 0) >= heatCelsius && isGoodTime($0.time) }),
           let temperature = hour.temperature {
            let text = Temperature.text(celsius: temperature)
            candidates.append(Alert(date: hour.time, update: WeatherUpdate(
                kind: .heat,
                title: "Temperature has reached \(text).",
                body: "Remember to stay hydrated and reapply sunscreen if outdoors.",
                headline: "It’s \(text) outside",
                subtitle: "Extreme heat in \(placeName).",
                why: "Sweating wears sunscreen off faster, so it may not last the full 2 hours.",
                whatToDo: "Drink plenty of water, stay in the shade when you can, and reapply sunscreen if you’re outdoors.",
                uv: UVReading(uv: hour.uv).index
            )))
        }

        // Rain moving in.
        if let index = hours.indices.first(where: { i in
            let hour = hours[i]
            let rainy = (hour.rainChance ?? 0) >= rainChance && [51, 53, 55, 61, 63, 65, 80, 81, 82, 95].contains(hour.weatherCode ?? 0)
            let wasDry = i == 0 || (hours[i - 1].rainChance ?? 0) < rainChance
            return rainy && wasDry && isGoodTime(hour.time)
        }) {
            let waterResistant = waterResistance != .none
            candidates.append(Alert(date: hours[index].time, update: WeatherUpdate(
                kind: .rain,
                title: "Rain detected.",
                body: waterResistant
                    ? "Your sunscreen is water resistant for \(waterResistance.rawValue), but reapply if you get soaked."
                    : "If your sunscreen isn’t water resistant, reapply after the rain.",
                headline: "Rain in \(placeName)",
                subtitle: "\(hours[index].rainChance ?? rainChance)% chance of rain right now.",
                why: "Rain can wash sunscreen off, and UV can still be strong between showers.",
                whatToDo: waterResistant
                    ? "Your water-resistant sunscreen should hold up for \(waterResistance.rawValue). If you get soaked, dry off and reapply."
                    : "Reapply after the rain if you were caught in it, especially before going back out in the sun.",
                uv: UVReading(uv: hours[index].uv).index
            )))
        }

        // Keep a few, spaced out, in time order.
        var picked: [Alert] = []
        for alert in candidates.sorted(by: { $0.date < $1.date }) {
            guard picked.count < maxPerDay else { break }
            if let last = picked.last, alert.date.timeIntervalSince(last.date) < minGap { continue }
            picked.append(alert)
        }
        return picked
    }
}
