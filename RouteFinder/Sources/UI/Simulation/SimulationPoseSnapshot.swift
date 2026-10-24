import Foundation

/// Immutable physics pose captured at the end of a simulation tick.
public struct SimulationPoseSnapshot: Sendable, Equatable {
    /// Distance along the densified route in meters.
    public let arcLengthMeters: Double
    /// Tractor / cab heading in degrees clockwise from north.
    public let bearingDegrees: Double
    /// Trailer heading in degrees clockwise from north (equals cab for rigid / passenger vehicles).
    public let trailerBearingDegrees: Double
    /// Longitudinal speed in meters per second.
    public let speedMps: Double
    /// World latitude from Ackermann integration (tractor rear axle / kingpin).
    public let latitude: Double
    /// World longitude from Ackermann integration (tractor rear axle / kingpin).
    public let longitude: Double
    /// Wall-clock instant when this snapshot was recorded.
    public let wallClockTime: ContinuousClock.Instant
    /// Elapsed simulation time in seconds when this snapshot was recorded.
    public let simulationTimeSeconds: Double

    /// Creates a simulation pose snapshot.
    public init(
        arcLengthMeters: Double,
        bearingDegrees: Double,
        trailerBearingDegrees: Double? = nil,
        speedMps: Double,
        latitude: Double,
        longitude: Double,
        wallClockTime: ContinuousClock.Instant,
        simulationTimeSeconds: Double
    ) {
        self.arcLengthMeters = arcLengthMeters
        self.bearingDegrees = bearingDegrees
        self.trailerBearingDegrees = trailerBearingDegrees ?? bearingDegrees
        self.speedMps = speedMps
        self.latitude = latitude
        self.longitude = longitude
        self.wallClockTime = wallClockTime
        self.simulationTimeSeconds = simulationTimeSeconds
    }
}
