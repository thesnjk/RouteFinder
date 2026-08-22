import Foundation

/// Immutable physics pose captured at the end of a simulation tick.
public struct SimulationPoseSnapshot: Sendable, Equatable {
    /// Distance along the densified route in meters.
    public let arcLengthMeters: Double
    /// Vehicle heading in degrees clockwise from north.
    public let bearingDegrees: Double
    /// Longitudinal speed in meters per second.
    public let speedMps: Double
    /// Wall-clock instant when this snapshot was recorded.
    public let wallClockTime: ContinuousClock.Instant
    /// Elapsed simulation time in seconds when this snapshot was recorded.
    public let simulationTimeSeconds: Double

    /// Creates a simulation pose snapshot.
    public init(
        arcLengthMeters: Double,
        bearingDegrees: Double,
        speedMps: Double,
        wallClockTime: ContinuousClock.Instant,
        simulationTimeSeconds: Double
    ) {
        self.arcLengthMeters = arcLengthMeters
        self.bearingDegrees = bearingDegrees
        self.speedMps = speedMps
        self.wallClockTime = wallClockTime
        self.simulationTimeSeconds = simulationTimeSeconds
    }
}
