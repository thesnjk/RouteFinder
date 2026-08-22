import CoreLocation
import Foundation

/// A single position sample from any location provider.
public struct NavigationPositionUpdate: Sendable {
    /// Geographic coordinate of the vehicle.
    public let coordinate: CLLocationCoordinate2D
    /// Movement bearing in degrees clockwise from north, when available.
    public let bearingDegrees: Double?
    /// Ground speed in meters per second, when available.
    public let speedMps: Double?
    /// Horizontal accuracy radius in meters.
    public let horizontalAccuracyMeters: Double
    /// Timestamp of the sample.
    public let timestamp: Date
    /// Source that produced this update.
    public let source: LocationProviderMode
    /// Optional precomputed arc length for simulation sources.
    public let arcLengthMeters: Double?
    /// Altitude in meters above mean sea level, when available.
    public let altitudeMeters: Double?
    /// Reliability indicator for fused hardware samples.
    public let qualityIndicator: TelemetryQualityIndicator

    /// Creates a navigation position update.
    public init(
        coordinate: CLLocationCoordinate2D,
        bearingDegrees: Double? = nil,
        speedMps: Double? = nil,
        altitudeMeters: Double? = nil,
        horizontalAccuracyMeters: Double = 0,
        timestamp: Date = Date(),
        source: LocationProviderMode,
        arcLengthMeters: Double? = nil,
        qualityIndicator: TelemetryQualityIndicator = .live
    ) {
        self.coordinate = coordinate
        self.bearingDegrees = bearingDegrees
        self.speedMps = speedMps
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.timestamp = timestamp
        self.source = source
        self.arcLengthMeters = arcLengthMeters
        self.qualityIndicator = qualityIndicator
    }
}
