import Foundation

/// Route drawing phase for procedural reveal and live progress tracking.
public enum RouteDrawingPhase: String, Sendable, Equatable {
    case idle
    case revealing
    case tracking
}

/// Arc-length progress state synchronized from simulation to the map layer.
public struct RouteProgressState: Equatable, Sendable {
    /// Current arc length along the route spine in meters.
    public let arcLengthMeters: Double
    /// Total route length in meters.
    public let totalLengthMeters: Double
    /// Normalized progress fraction in `[0, 1]`.
    public let progressFraction: Double
    /// Drawing phase for reveal vs live tracking.
    public let phase: RouteDrawingPhase

    /// Creates route progress state.
    public init(
        arcLengthMeters: Double,
        totalLengthMeters: Double,
        progressFraction: Double,
        phase: RouteDrawingPhase = .tracking
    ) {
        self.arcLengthMeters = arcLengthMeters
        self.totalLengthMeters = totalLengthMeters
        self.progressFraction = progressFraction
        self.phase = phase
    }

    /// Builds progress from arc length and total route length.
    public static func from(
        arcLengthMeters: Double,
        totalLengthMeters: Double,
        phase: RouteDrawingPhase = .tracking
    ) -> RouteProgressState {
        let fraction: Double
        if totalLengthMeters > 0 {
            fraction = min(1, max(0, arcLengthMeters / totalLengthMeters))
        } else {
            fraction = 0
        }
        return RouteProgressState(
            arcLengthMeters: arcLengthMeters,
            totalLengthMeters: totalLengthMeters,
            progressFraction: fraction,
            phase: phase
        )
    }
}
