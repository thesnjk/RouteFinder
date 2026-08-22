import Foundation

/// Precomputed travel cost matrix from a routing API.
public struct RoutingMatrix: Sendable, Equatable {
    /// Travel durations in seconds between location pairs.
    public let durations: [[Double]]
    /// Travel distances in meters between location pairs.
    public let distances: [[Double]]
    /// Maps matrix row index to original waypoint index.
    public let locationIndices: [Int]

    /// Creates a routing matrix.
    public init(
        durations: [[Double]],
        distances: [[Double]],
        locationIndices: [Int]
    ) {
        self.durations = durations
        self.distances = distances
        self.locationIndices = locationIndices
    }

    /// Primary cost matrix for TSP heuristics, preferring duration over distance.
    public var primaryCostMatrix: [[Double]] {
        if !durations.isEmpty, durations.count == distances.count {
            return durations
        }
        return distances
    }
}
