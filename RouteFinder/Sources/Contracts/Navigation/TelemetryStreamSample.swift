import CoreLocation
import Foundation

/// Unified telemetry sample merging position, course, speed, and altitude.
public struct TelemetryStreamSample: Sendable {
    /// Geographic coordinate of the vehicle.
    public let coordinate: CLLocationCoordinate2D
    /// True course heading in degrees clockwise from north, when available.
    public let courseDegrees: Double?
    /// Ground speed in meters per second, when available.
    public let speedMps: Double?
    /// Altitude in meters above mean sea level, when available.
    public let altitudeMeters: Double?
    /// Horizontal accuracy radius in meters.
    public let horizontalAccuracyMeters: Double
    /// Timestamp of the sample.
    public let timestamp: Date
    /// Source that produced this sample.
    public let sourceMode: LocationProviderMode
    /// Optional precomputed arc length for simulation sources.
    public let arcLengthMeters: Double?
    /// Reliability indicator for fused hardware samples.
    public let qualityIndicator: TelemetryQualityIndicator
    /// Monotonic revision counter for coalescing duplicate ticks.
    public let revision: UInt64

    /// Creates a telemetry stream sample.
    public init(
        coordinate: CLLocationCoordinate2D,
        courseDegrees: Double? = nil,
        speedMps: Double? = nil,
        altitudeMeters: Double? = nil,
        horizontalAccuracyMeters: Double = 0,
        timestamp: Date = Date(),
        sourceMode: LocationProviderMode,
        arcLengthMeters: Double? = nil,
        qualityIndicator: TelemetryQualityIndicator = .live,
        revision: UInt64 = 0
    ) {
        self.coordinate = coordinate
        self.courseDegrees = courseDegrees
        self.speedMps = speedMps
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.timestamp = timestamp
        self.sourceMode = sourceMode
        self.arcLengthMeters = arcLengthMeters
        self.qualityIndicator = qualityIndicator
        self.revision = revision
    }

    /// Converts this sample into a navigation position update.
    public var navigationPositionUpdate: NavigationPositionUpdate {
        NavigationPositionUpdate(
            coordinate: coordinate,
            bearingDegrees: courseDegrees,
            speedMps: speedMps,
            altitudeMeters: altitudeMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            timestamp: timestamp,
            source: sourceMode,
            arcLengthMeters: arcLengthMeters,
            qualityIndicator: qualityIndicator
        )
    }
}
