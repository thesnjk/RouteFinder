import Contracts
import CoreLocation
import Foundation

/// Converts and formats speed telemetry based on coordinate geography.
public struct TelemetryUnitConverter: Sendable {
    private static let kmhToMphFactor: Double = 0.621371
    private static let mphToKmhFactor: Double = 1.60934

    /// Infers the regional measurement system from a WGS84 coordinate.
    public static func measurementSystem(for coordinate: CLLocationCoordinate2D) -> RegionalMeasurementSystem {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        if isUnitedKingdom(latitude: latitude, longitude: longitude) {
            return .imperial
        }
        if isUnitedStates(latitude: latitude, longitude: longitude) {
            return .imperial
        }
        return .metric
    }

    /// Resolves dial / turn-list display units from registration origin, falling back to geography.
    ///
    /// UK and US plates map to imperial (mph); EU plates map to metric (km/h).
    public static func displayMeasurementSystem(
        forRegistration registration: String,
        fallbackCoordinate: CLLocationCoordinate2D
    ) -> RegionalMeasurementSystem {
        let trimmed = registration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            switch RegionalPlateFallbackParser.detectRegion(from: trimmed) {
            case .uk, .us:
                return .imperial
            case .eu:
                return .metric
            case .auto:
                break
            }
        }
        return measurementSystem(for: fallbackCoordinate)
    }

    /// Formats a canonical km/h speed limit value for the requested display system.
    ///
    /// - Parameters:
    ///   - rawOsmValue: Speed limit in kilometers per hour.
    ///   - targetSystem: Display measurement system.
    /// - Returns: Localized speed string such as `"50 km/h"` or `"31 mph"`.
    public static func formatSpeedLimit(
        rawOsmValue: Double,
        targetSystem: RegionalMeasurementSystem
    ) -> String {
        switch targetSystem {
        case .imperial:
            let convertedMilesPerHour = Int(round(rawOsmValue * Self.kmhToMphFactor))
            return "\(convertedMilesPerHour) mph"
        case .metric:
            let exactKmPerHour = Int(round(rawOsmValue))
            return "\(exactKmPerHour) km/h"
        }
    }

    /// Normalizes a regional speed value to kilometers per hour for internal physics.
    public static func normalizeSpeedToKmh(
        rawValue: Double,
        nativeSystem: RegionalMeasurementSystem
    ) -> Double {
        switch nativeSystem {
        case .metric:
            return rawValue
        case .imperial:
            return rawValue * Self.mphToKmhFactor
        }
    }

    /// Formats an internal km/h speed for display at the given coordinate.
    public static func formatSpeedKmh(
        _ speedKmh: Double,
        at coordinate: CLLocationCoordinate2D
    ) -> String {
        let targetSystem = measurementSystem(for: coordinate)
        switch targetSystem {
        case .metric:
            return "\(Int(round(speedKmh))) km/h"
        case .imperial:
            let mph = speedKmh * Self.kmhToMphFactor
            return "\(Int(round(mph))) mph"
        }
    }

    /// Formats an internal km/h speed for display when no coordinate is available.
    public static func formatSpeedKmh(_ speedKmh: Double, system: RegionalMeasurementSystem) -> String {
        switch system {
        case .metric:
            return "\(Int(round(speedKmh))) km/h"
        case .imperial:
            let mph = speedKmh * Self.kmhToMphFactor
            return "\(Int(round(mph))) mph"
        }
    }

    private static func isUnitedKingdom(latitude: Double, longitude: Double) -> Bool {
        latitude >= 49.5 && latitude <= 61.0 && longitude >= -8.5 && longitude <= 2.0
    }

    private static func isUnitedStates(latitude: Double, longitude: Double) -> Bool {
        latitude >= 24.0 && latitude <= 49.5 && longitude >= -125.0 && longitude <= -66.0
    }
}
