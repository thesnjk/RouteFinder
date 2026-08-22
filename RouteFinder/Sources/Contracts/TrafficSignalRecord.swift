import Foundation

/// Current phase of a traffic signal cycle.
public enum TrafficSignalPhase: String, Codable, Sendable, Hashable, CaseIterable {
    /// Green — proceed.
    case green
    /// Amber — prepare to stop.
    case amber
    /// Red — stop required.
    case red
}

/// A traffic signal node projected onto the route polyline.
public struct TrafficSignalRecord: Codable, Equatable, Sendable, Hashable, Identifiable {
    /// OSM node identifier or synthetic UUID.
    public let id: Int64
    /// Signal location.
    public let coordinate: RoutingCoordinate
    /// Arc length along the route polyline in meters.
    public let arcLengthMeters: Double
    /// Approach bearing in degrees (0–360).
    public let bearingDegrees: Double
    /// Current simulated phase.
    public let phase: TrafficSignalPhase

    /// Creates a traffic signal record.
    public init(
        id: Int64,
        coordinate: RoutingCoordinate,
        arcLengthMeters: Double,
        bearingDegrees: Double,
        phase: TrafficSignalPhase = .green
    ) {
        self.id = id
        self.coordinate = coordinate
        self.arcLengthMeters = arcLengthMeters
        self.bearingDegrees = bearingDegrees
        self.phase = phase
    }
}
