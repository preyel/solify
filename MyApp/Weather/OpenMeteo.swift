import Foundation

/// Talks to Open-Meteo (open-meteo.com), a free weather service that needs no account or key.
/// Its free plan is for non-commercial use; if Solify ever makes money, switch to their paid
/// plan or to Apple's WeatherKit.
enum OpenMeteo {
    /// A city from search results.
    struct Place: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country: String?

        /// Like "Chandler, Arizona".
        var displayName: String {
            [name, admin1].compactMap { $0 }.joined(separator: ", ")
        }
    }

    static func forecast(latitude: Double, longitude: Double) async throws -> UVForecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "uv_index,temperature_2m,weather_code,precipitation_probability"),
            URLQueryItem(name: "daily", value: "uv_index_max,sunrise,sunset,weather_code,precipitation_probability_max,temperature_2m_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "10"),
        ]
        let response: ForecastResponse = try await fetch(components.url!)

        let hourly = response.hourly
        let hours = hourly.time.indices.compactMap { index -> UVForecast.Hour? in
            guard let uv = hourly.uvIndex[index] else { return nil }
            return UVForecast.Hour(
                time: Date(timeIntervalSince1970: hourly.time[index]),
                uv: max(0, uv),
                temperature: hourly.temperature2m?[safe: index] ?? nil,
                weatherCode: hourly.weatherCode?[safe: index] ?? nil,
                rainChance: hourly.precipitationProbability?[safe: index] ?? nil
            )
        }
        let daily = response.daily
        let days = daily.time.indices.map { index in
            UVForecast.Day(
                date: Date(timeIntervalSince1970: daily.time[index]),
                maxUV: max(0, daily.uvIndexMax[index] ?? 0),
                sunrise: daily.sunrise[index].map { Date(timeIntervalSince1970: $0) },
                sunset: daily.sunset[index].map { Date(timeIntervalSince1970: $0) },
                weatherCode: daily.weatherCode[index],
                rainChance: daily.precipitationProbabilityMax?[safe: index] ?? nil,
                maxTemperature: daily.temperature2mMax?[safe: index] ?? nil
            )
        }
        return UVForecast(timeZoneID: response.timezone, hours: hours, days: days, fetchedAt: .now)
    }

    static func searchCities(_ query: String) async throws -> [Place] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: "en"),
        ]
        let response: SearchResponse = try await fetch(components.url!)
        return response.results ?? []
    }

    private static func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // The shape of Open-Meteo's replies.

    private struct ForecastResponse: Decodable {
        let timezone: String
        let hourly: Hourly
        let daily: Daily

        struct Hourly: Decodable {
            let time: [Double]
            let uvIndex: [Double?]
            let temperature2m: [Double?]?
            let weatherCode: [Int?]?
            let precipitationProbability: [Int?]?
        }

        struct Daily: Decodable {
            let time: [Double]
            let uvIndexMax: [Double?]
            let sunrise: [Double?]
            let sunset: [Double?]
            let weatherCode: [Int?]
            let precipitationProbabilityMax: [Int?]?
            let temperature2mMax: [Double?]?
        }
    }

    private struct SearchResponse: Decodable {
        let results: [Place]?
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
