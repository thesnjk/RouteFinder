import Foundation

/// Geometry-index-aligned speed limit data extracted from an external routing response.
public struct SegmentSpeedLimitSource: Sendable, Equatable, Codable {
    /// Speed limits in km/h aligned to raw routing coordinates before densification.
    public let rawGeometrySpeedLimitsKmh: [Double?]
    /// Step-scoped limits mapped to raw geometry index ranges via ORS `way_points`.
    public let stepSpeedRanges: [ORSStepSpeedRange]

    /// Creates a segment speed limit source bundle.
    public init(
        rawGeometrySpeedLimitsKmh: [Double?] = [],
        stepSpeedRanges: [ORSStepSpeedRange] = []
    ) {
        self.rawGeometrySpeedLimitsKmh = rawGeometrySpeedLimitsKmh
        self.stepSpeedRanges = stepSpeedRanges
    }
}

/// Inclusive raw-geometry index range with an optional explicit speed limit from an ORS step.
public struct ORSStepSpeedRange: Sendable, Equatable, Codable {
    /// Start index into the raw geometry coordinate array.
    public let startIndex: Int
    /// End index into the raw geometry coordinate array.
    public let endIndex: Int
    /// Normalized speed limit in km/h for this step span.
    public let speedLimitKmh: Double?

    /// Creates a step speed range mapping.
    public init(startIndex: Int, endIndex: Int, speedLimitKmh: Double?) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.speedLimitKmh = speedLimitKmh
    }
}

/// Provenance of a resolved speed limit along the route spine.
public enum SpeedLimitSource: Sendable, Equatable {
    /// Regional default for local/residential segments.
    case regionalDefault
    /// Major-road vehicle ceiling (motorway, A-road, M-road, etc.).
    case majorRoadCeiling
    /// Design speed inferred from routing step distance and duration.
    case designSpeed
    /// Explicit limit from routing payload (e.g. ORS maximum_speed or geometry maxspeed).
    case orsExplicit
    /// Design speed corrected from imperial mph sign value to km/h.
    case correctedImperial
}

/// Resolved speed limit sample along a route arc length.
public struct SpeedLimitSample: Sendable, Equatable {
    /// Arc length in meters from route start.
    public let arcLength: Double
    /// Legal speed in km/h.
    public let speedKmh: Double
    /// How the limit was determined.
    public let source: SpeedLimitSource

    /// Creates a speed limit sample.
    public init(arcLength: Double, speedKmh: Double, source: SpeedLimitSource) {
        self.arcLength = arcLength
        self.speedKmh = speedKmh
        self.source = source
    }
}
