import SwiftUI

/// The UV forecast for one place: every hour for the next 10 days, plus a summary of each day.
struct UVForecast: Codable {
    struct Hour: Codable, Identifiable {
        let time: Date
        let uv: Double
        /// °C.
        var temperature: Double? = nil
        /// Standard weather code (0 = clear sky, 3 = overcast, 61 = rain, …).
        var weatherCode: Int? = nil
        /// 0–100%.
        var rainChance: Int? = nil
        var id: Date { time }
    }

    struct Day: Codable, Identifiable {
        /// Midnight at the start of the day, in the place's time zone.
        let date: Date
        let maxUV: Double
        let sunrise: Date?
        let sunset: Date?
        /// Standard weather code (0 = clear sky, 3 = overcast, 61 = rain, …).
        let weatherCode: Int?
        /// Highest chance of rain during the day, 0–100%.
        var rainChance: Int? = nil
        /// °C.
        var maxTemperature: Double? = nil
        var id: Date { date }
    }

    let timeZoneID: String
    let hours: [Hour]
    let days: [Day]
    let fetchedAt: Date

    /// The forecast place's time zone (it can differ from the phone's if you picked a far-away city).
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func day(containing date: Date) -> Day? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func hours(on day: Day) -> [Hour] {
        hours.filter { calendar.isDate($0.time, inSameDayAs: day.date) }
    }

    /// The UV at any moment, blending between the two nearest hours.
    func uv(at date: Date) -> Double? {
        guard let nextIndex = hours.firstIndex(where: { $0.time > date }) else { return nil }
        guard nextIndex > 0 else { return hours[nextIndex].uv }
        let before = hours[nextIndex - 1], after = hours[nextIndex]
        let fraction = date.timeIntervalSince(before.time) / after.time.timeIntervalSince(before.time)
        return before.uv + (after.uv - before.uv) * fraction
    }

    /// The forecast hour that `date` falls in.
    func hour(at date: Date) -> Hour? {
        hours.last { $0.time <= date && date.timeIntervalSince($0.time) < 3600 }
    }

    /// The highest UV from `date` until the end of that day, or nil if there's no data.
    func maxUV(fromTimeToEndOfDay date: Date) -> Double? {
        let rest = hours.filter { $0.time.addingTimeInterval(3600) > date && calendar.isDate($0.time, inSameDayAs: date) }
        return rest.map(\.uv).max()
    }

    /// The hour when UV is highest on that day.
    func peakHour(on day: Day) -> Hour? {
        hours(on: day).max { $0.uv < $1.uv }
    }

    /// The stretch of time around the peak when UV stays close to its highest (within 85%),
    /// like 12 PM – 3 PM. Nil if UV stays low all day.
    func peakWindow(on day: Day) -> ClosedRange<Date>? {
        let dayHours = hours(on: day)
        guard let peakIndex = dayHours.indices.max(by: { dayHours[$0].uv < dayHours[$1].uv }),
              dayHours[peakIndex].uv >= 3
        else { return nil }

        let threshold = dayHours[peakIndex].uv * 0.85
        var start = peakIndex, end = peakIndex
        while start > 0, dayHours[start - 1].uv >= threshold { start -= 1 }
        while end < dayHours.count - 1, dayHours[end + 1].uv >= threshold { end += 1 }
        return dayHours[start].time...dayHours[end].time.addingTimeInterval(3600)
    }
}

extension UVForecast.Day {
    var condition: WeatherCondition {
        switch weatherCode ?? 0 {
        case 0...1: .clear
        case 51...67, 80...82, 95...99: .rainy
        default: .cloudy
        }
    }

    /// An SF Symbol for the day's weather.
    var weatherSymbol: String {
        switch weatherCode ?? 0 {
        case 0: "sun.max.fill"
        case 1...2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45...48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67: "cloud.rain.fill"
        case 71...77, 85...86: "cloud.snow.fill"
        case 80...82: "cloud.heavyrain.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.sun.fill"
        }
    }

    /// Color for the sun, rain or snow part of the weather icon.
    var weatherAccent: Color {
        switch weatherCode ?? 0 {
        case 51...67, 80...82: .blue
        case 71...77, 85...86: .cyan
        case 95...99: .yellow
        default: .orange
        }
    }

    var weatherDescription: String {
        switch weatherCode ?? 0 {
        case 0: "Clear"
        case 1...2: "Partly cloudy"
        case 3: "Cloudy"
        case 45...48: "Fog"
        case 51...57: "Drizzle"
        case 61...67, 80...82: "Rain"
        case 71...77, 85...86: "Snow"
        case 95...99: "Thunderstorms"
        default: "Partly cloudy"
        }
    }
}
