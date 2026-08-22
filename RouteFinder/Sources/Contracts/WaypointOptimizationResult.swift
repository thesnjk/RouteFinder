import Foundation

/// Result of reordering intermediate waypoint stops.
public struct WaypointOptimizationResult: Sendable, Hashable {
    /// Permutation of indices into the original `intermediateStops` array.
    public let optimizedStopIndices: [Int]
    /// Whether the result came from the local heuristic tier.
    public let usedLocalTier: Bool

    /// Creates an optimization result.
    public init(optimizedStopIndices: [Int], usedLocalTier: Bool) {
        self.optimizedStopIndices = optimizedStopIndices
        self.usedLocalTier = usedLocalTier
    }

    /// Reorders an array of intermediate stops according to the optimized indices.
    public func reordered<T>(_ stops: [T]) -> [T] {
        optimizedStopIndices.map { stops[$0] }
    }
}
