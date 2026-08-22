import Foundation

/// Aggregated metrics for a calculated route.
public struct RouteMetrics: Sendable, Hashable {
    /// Total route distance in meters.
    public let totalDistance: Double
    /// Actual estimated travel time in seconds (not search cost).
    public let totalTime: TimeInterval
    /// Sum of edge costs used by the pathfinding algorithm.
    public let searchCost: Double
    /// Number of speed camera segments on the route.
    public let speedCameraCount: Int
    /// Number of toll segments on the route.
    public let tollSegmentCount: Int
    /// Number of ferry segments on the route.
    public let ferrySegmentCount: Int
    /// Number of tunnel segments on the route.
    public let tunnelSegmentCount: Int

    /// Creates route metrics with the given values.
    public init(
        totalDistance: Double,
        totalTime: TimeInterval,
        searchCost: Double,
        speedCameraCount: Int,
        tollSegmentCount: Int,
        ferrySegmentCount: Int,
        tunnelSegmentCount: Int
    ) {
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.searchCost = searchCost
        self.speedCameraCount = speedCameraCount
        self.tollSegmentCount = tollSegmentCount
        self.ferrySegmentCount = ferrySegmentCount
        self.tunnelSegmentCount = tunnelSegmentCount
    }

    /// Empty metrics for failed routes.
    public static let empty = RouteMetrics(
        totalDistance: 0,
        totalTime: 0,
        searchCost: 0,
        speedCameraCount: 0,
        tollSegmentCount: 0,
        ferrySegmentCount: 0,
        tunnelSegmentCount: 0
    )
}
