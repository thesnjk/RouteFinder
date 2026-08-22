#if os(iOS)
import CoreLocation
import Foundation

/// GPS location updates for follow-mode navigation on iOS.
@MainActor
public final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    public var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    private let manager = CLLocationManager()
    private var isRunning = false

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    /// Requests permission and begins location updates when authorized.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    /// Stops location updates.
    public func stop() {
        isRunning = false
        manager.stopUpdatingLocation()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        onLocationUpdate?(coordinate)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
#endif
