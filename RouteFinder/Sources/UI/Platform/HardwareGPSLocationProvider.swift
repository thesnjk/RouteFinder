#if os(iOS)
import Contracts
import CoreLocation
import Foundation

/// Location provider powered by Apple CoreLocation hardware GPS.
@MainActor
public final class HardwareGPSLocationProvider: NSObject, LocationProvider, @preconcurrency CLLocationManagerDelegate {
    public let mode: LocationProviderMode = .hardwareGPS
    public private(set) var isActive = false
    public var accuracyThresholdMeters: Double = 25

    private weak var delegate: LocationProviderDelegate?
    private let manager = CLLocationManager()
    private var isUpdatingHeading = false
    private var lastHeading: CLHeading?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
    }

    public func setDelegate(_ delegate: LocationProviderDelegate?) {
        self.delegate = delegate
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    public func stop() {
        isActive = false
        manager.stopUpdatingLocation()
        stopHeadingUpdatesIfNeeded()
    }

    /// Enables compass heading updates for low-speed bearing fallback.
    public func startHeadingUpdatesIfNeeded() {
        guard !isUpdatingHeading else { return }
        isUpdatingHeading = true
        manager.startUpdatingHeading()
    }

    /// Disables compass heading updates.
    public func stopHeadingUpdatesIfNeeded() {
        guard isUpdatingHeading else { return }
        isUpdatingHeading = false
        manager.stopUpdatingHeading()
        lastHeading = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive, let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= accuracyThresholdMeters else { return }

        let speed = location.speed >= 0 ? location.speed : nil
        let course = location.course >= 0 ? location.course : nil
        let bearing = resolvedBearing(speed: speed, course: course)

        let update = NavigationPositionUpdate(
            coordinate: location.coordinate,
            bearingDegrees: bearing,
            speedMps: speed,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            timestamp: location.timestamp,
            source: .hardwareGPS
        )
        delegate?.locationProvider(self, didReceive: update)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        delegate?.locationProvider(self, didChangeAuthorization: manager.authorizationStatus)
        if isActive,
           manager.authorizationStatus == .authorizedWhenInUse
               || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationProvider(self, didFailWithError: error)
    }

    private func resolvedBearing(speed: Double?, course: Double?) -> Double? {
        if let speed, speed >= 1, let course {
            return course
        }
        if let heading = lastHeading?.trueHeading, heading >= 0 {
            return heading
        }
        if let heading = lastHeading?.magneticHeading, heading >= 0 {
            return heading
        }
        return course
    }
}
#endif
