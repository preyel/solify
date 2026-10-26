import Foundation

/// Rough sky conditions; changes what the notifications say.
enum WeatherCondition {
    case clear, cloudy, rainy
}

struct DayForecast {
    /// The highest UV the day will reach.
    let peakUV: UVReading
    let condition: WeatherCondition
    /// Highest chance of rain during the day, 0–100%.
    let rainChance: Int?
    /// °C.
    let maxTemperature: Double?
}

/// Quick answers from the saved forecast, for the notifications.
/// Nil when there's no forecast yet (no location chosen, or no internet so far).
enum Weather {
    static func forecast(for day: Date) -> DayForecast? {
        guard let day = WeatherStore.shared.forecast?.day(containing: day) else { return nil }
        return DayForecast(peakUV: UVReading(uv: day.maxUV), condition: day.condition, rainChance: day.rainChance, maxTemperature: day.maxTemperature)
    }

    static func uv(at time: Date) -> UVReading? {
        WeatherStore.shared.forecast?.uv(at: time).map(UVReading.init(uv:))
    }
}
