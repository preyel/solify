import CoreLocation
import Foundation
import Observation

/// The place the forecast is for.
struct SavedLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    /// True if it follows the phone's location; false if the user typed a city.
    var isCurrent: Bool
}

/// Holds the UV forecast for the whole app (Home, Forecast and notifications all read from here)
/// and saves it on the phone so it's there right away next launch.
@Observable
final class WeatherStore {
    static let shared = WeatherStore()

    /// How old the forecast can get before it's fetched again.
    private static let maxAge: TimeInterval = 30 * 60

    private(set) var location: SavedLocation? {
        didSet { save(location, key: Self.locationKey) }
    }
    private(set) var forecast: UVForecast? {
        didSet { save(forecast, key: Self.forecastKey) }
    }
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private static let locationKey = "savedLocation"
    private static let forecastKey = "cachedForecast"

    private init() {
        location = Self.load(SavedLocation.self, key: Self.locationKey)
        forecast = Self.load(UVForecast.self, key: Self.forecastKey)
    }

    /// Fetches a new forecast if there's none yet or it's more than 30 minutes old.
    func refreshIfNeeded() async {
        guard location != nil, !isLoading else { return }
        if let forecast, Date.now.timeIntervalSince(forecast.fetchedAt) < Self.maxAge { return }
        await refresh()
    }

    /// `updateLocation` is false in the background, where there isn't time to wait for GPS.
    func refresh(updateLocation: Bool = true) async {
        guard var place = location, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // If following the phone, check whether it has moved, but only if we already have
        // permission. Never pop up the location question on our own; if "Allow Once" has
        // expired, just keep using the last place we found.
        if updateLocation, place.isCurrent, LocationService.isAuthorized, let here = try? await LocationService.currentLocation() {
            place.latitude = here.coordinate.latitude
            place.longitude = here.coordinate.longitude
            place.name = await LocationService.placeName(for: here)
            location = place
        }
        await loadForecast(for: place, reason: .weatherUpdate)
    }

    /// Switches to the phone's location. Throws `LocationError.denied` if permission is off.
    func useCurrentLocation() async throws {
        isLoading = true
        defer { isLoading = false }
        let here = try await LocationService.currentLocation()
        let name = await LocationService.placeName(for: here)
        let place = SavedLocation(name: name, latitude: here.coordinate.latitude, longitude: here.coordinate.longitude, isCurrent: true)
        location = place
        forecast = nil
        await loadForecast(for: place, reason: .userAction)
    }

    func useCity(_ city: OpenMeteo.Place) async {
        isLoading = true
        defer { isLoading = false }
        let place = SavedLocation(name: city.displayName, latitude: city.latitude, longitude: city.longitude, isCurrent: false)
        location = place
        forecast = nil
        await loadForecast(for: place, reason: .userAction)
    }

    private func loadForecast(for place: SavedLocation, reason: Reminders.Reason) async {
        do {
            forecast = try await OpenMeteo.forecast(latitude: place.latitude, longitude: place.longitude)
            errorMessage = nil
            // The notifications depend on the weather, so line them up again with the new numbers.
            if UserDefaults.standard.bool(forKey: StorageKey.hasSeenWelcome) {
                await Reminders.refreshAll(reason: reason)
            }
        } catch {
            errorMessage = "Couldn’t load the UV forecast. Check your internet connection and try again."
        }
    }

    // Saving to and loading from the phone.

    private func save<T: Encodable>(_ value: T?, key: String) {
        let data = value.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
