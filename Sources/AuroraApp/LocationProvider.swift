import Foundation
import CoreLocation
import Combine

/// Thin CoreLocation wrapper that yields a one-shot coordinate for the circadian
/// schedule. Degrades gracefully: if permission is denied or unavailable, the
/// app keeps using the manually-set latitude/longitude.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var lastError: String?

    /// Called on the main actor with (latitude, longitude) when a fix arrives.
    var onUpdate: ((Double, Double) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        lastError = nil
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        let lat = coord.latitude, lon = coord.longitude
        Task { @MainActor in self.onUpdate?(lat, lon) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.lastError = message }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorization = self.manager.authorizationStatus
            if self.authorization == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }
}
