import Contracts
import CoreLocation
import Foundation

/// Native unit for a raw speed-limit value from routing or map data.
public enum SpeedLimitUnit: Sendable, Equatable {
    /// Value is already in kilometers per hour.
    case kmh
    /// Value is in miles per hour (UK / US signage).
    case mph
}

/// Converts regional speed values to canonical km/h for simulation physics.
public enum SpeedLimitNormalizer: Sendable {
    /// Common UK/US mph sign values that appear as bare numbers in routing payloads.
    private static let imperialSignValuesMph: Set<Double> = [20, 30, 40, 48, 50, 56, 60, 70]

    /// Converts a raw limit to canonical km/h using the declared native unit.
    public static func toKmh(rawValue: Double, nativeUnit: SpeedLimitUnit) -> Double {
        guard rawValue.isFinite, rawValue > 0 else { return 0 }
        switch nativeUnit {
        case .kmh:
            return rawValue
        case .mph:
            return TelemetryUnitConverter.normalizeSpeedToKmh(
                rawValue: rawValue,
                nativeSystem: .imperial
            )
        }
    }

    /// Infers the native unit from geographic context and common sign-value heuristics.
    public static func inferUnit(
        for rawValue: Double,
        coordinate: CLLocationCoordinate2D
    ) -> SpeedLimitUnit {
        let system = TelemetryUnitConverter.measurementSystem(for: coordinate)
        switch system {
        case .metric:
            return .kmh
        case .imperial:
            if Self.imperialSignValuesMph.contains(where: { abs($0 - rawValue) < 0.5 }) {
                return .mph
            }
            if rawValue <= 130 {
                return .mph
            }
            return .kmh
        }
    }

    /// Normalizes a raw speed value using geographic inference when unit is unknown.
    public static func normalizeToKmh(
        rawValue: Double,
        coordinate: CLLocationCoordinate2D
    ) -> Double {
        let unit = inferUnit(for: rawValue, coordinate: coordinate)
        return toKmh(rawValue: rawValue, nativeUnit: unit)
    }

    /// Corrects ORS design-speed when imperial regions treat mph sign values as km/h.
    public static func correctDesignSpeedKmh(
        designKmh: Double,
        measurementSystem: RegionalMeasurementSystem,
        roadLabel: String?
    ) -> Double {
        guard measurementSystem == .imperial else { return designKmh }

        let rounded = (designKmh * 10).rounded() / 10
        if Self.imperialSignValuesMph.contains(where: { abs($0 - rounded) < 0.6 }) {
            return toKmh(rawValue: rounded, nativeUnit: .mph)
        }

        if isLikelyNationalSpeedLimitRoad(roadLabel), rounded >= 55, rounded <= 75 {
            return toKmh(rawValue: 60, nativeUnit: .mph)
        }

        return designKmh
    }

    /// Returns true when the road label suggests a national-speed-limit major road in the UK.
    public static func isLikelyNationalSpeedLimitRoad(_ roadLabel: String?) -> Bool {
        guard let roadLabel else { return false }
        let lower = roadLabel.lowercased()
        if lower.contains("national speed limit") || lower.contains("nsl") { return true }
        if lower.contains("dual carriageway") || lower.contains("trunk") { return true }
        if roadLabel.range(of: #"\bM\d+\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }
}
