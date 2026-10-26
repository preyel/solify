import CoreLocation
import MapKit

/// Gets the phone's location once, asking permission the first time.
enum LocationService {
    enum LocationError: Error {
        /// The user said no (or location is turned off for the whole phone).
        case denied
        case unavailable
    }

    /// True if Solify can read the location right now without asking.
    /// ("Allow Once" only counts until you leave the app.)
    static var isAuthorized: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Asks for "While Using the App" permission if needed, then returns where the phone is.
    /// Gives up after 15 seconds (using the last known location if there is one).
    static func currentLocation() async throws -> CLLocation {
        try await OneTimeLocation().fetch()
    }

    /// A short name for a spot, like "Chandler, AZ".
    static func placeName(for location: CLLocation) async -> String {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first
        else { return "Current Location" }
        return item.addressRepresentations?.cityWithContext ?? item.name ?? "Current Location"
    }
}

/// Wraps Apple's one-time location request (`requestLocation`) so it can be awaited.
private final class OneTimeLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetch() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start()
            // Don't spin forever.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                if let last = self.manager.location {
                    self.finish(.success(last))
                } else {
                    self.finish(.failure(LocationService.LocationError.unavailable))
                }
            }
        }
    }

    private func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            // Shows Apple's popup; the answer arrives in locationManagerDidChangeAuthorization.
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.failure(LocationService.LocationError.denied))
        default:
            manager.requestLocation()
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }

    // Apple calls these on the main thread (where the manager was made).

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard continuation != nil, manager.authorizationStatus != .notDetermined else { return }
            start()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let location = locations.last { finish(.success(location)) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            if let last = manager.location {
                finish(.success(last))
            } else if (error as? CLError)?.code == .denied {
                finish(.failure(LocationService.LocationError.denied))
            } else {
                finish(.failure(LocationService.LocationError.unavailable))
            }
        }
    }
}
