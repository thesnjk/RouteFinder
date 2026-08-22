import Foundation

/// Legal speed ceilings by vehicle class for traffic flow interpretation.
public enum VehicleSpeedLimits: Sendable {
    // MARK: - Imperial (UK / US) — mph equivalents stored as km/h

    /// HGV/truck ceiling for major roads (60 mph).
    public static let hgvMajorRoadSpeedKmh = 96.0
    /// Passenger car ceiling for major roads (70 mph).
    public static let carMajorRoadSpeedKmh = 112.0
    /// Default legal speed for local/residential segments (30 mph).
    public static let defaultSpeedKmh = 48.0

    // MARK: - Metric (continental Europe / Norway)

    /// HGV/truck ceiling for major roads in metric territories (80 km/h).
    public static let metricHgvMajorRoadSpeedKmh = 80.0
    /// Passenger car ceiling for major roads in metric territories (130 km/h).
    public static let metricCarMajorRoadSpeedKmh = 130.0
    /// Default legal speed for local/residential segments in metric territories (50 km/h).
    public static let metricDefaultSpeedKmh = 50.0

    /// Returns regional speed limits for the given measurement system.
    public static func limits(for system: RegionalMeasurementSystem) -> (
        defaultSpeedKmh: Double,
        hgvMajorRoadSpeedKmh: Double,
        carMajorRoadSpeedKmh: Double
    ) {
        switch system {
        case .imperial:
            return (defaultSpeedKmh, hgvMajorRoadSpeedKmh, carMajorRoadSpeedKmh)
        case .metric:
            return (metricDefaultSpeedKmh, metricHgvMajorRoadSpeedKmh, metricCarMajorRoadSpeedKmh)
        }
    }
}

/// Regional measurement system used for speed limit display and OSM parsing.
public enum RegionalMeasurementSystem: Sendable, Equatable {
    /// Kilometers per hour — Norway and continental Europe.
    case metric
    /// Miles per hour — United Kingdom and United States.
    case imperial
}
