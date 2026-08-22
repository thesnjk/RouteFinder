import CoreLocation
import Foundation

/// Determines when a location change is large enough to warrant a new weather fetch.
public enum SignificantLocationGate: Sendable {
    /// Default distance threshold for refreshing road conditions from weather data.
    public static let defaultWeatherFetchThresholdMeters: Double = 5_000

    /// Returns `true` when no prior location exists or the new fix is at least `thresholdMeters` away.
    public static func shouldFetch(
        from lastLocation: CLLocation?,
        to newLocation: CLLocation,
        thresholdMeters: Double = defaultWeatherFetchThresholdMeters
    ) -> Bool {
        guard let lastLocation else { return true }
        return lastLocation.distance(from: newLocation) >= thresholdMeters
    }
}
