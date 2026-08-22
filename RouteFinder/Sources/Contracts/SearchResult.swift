import Foundation

/// Outcome of a pathfinding search including metrics and instructions.
public struct SearchResult: Sendable {
    /// Ordered list of node IDs from start to destination.
    public let path: [String]
    /// Total route distance in meters.
    public let totalDistance: Double
    /// Total estimated travel time in seconds.
    public let totalTime: TimeInterval
    /// Number of nodes visited during search.
    public let nodesVisited: Int
    /// Wall-clock runtime of the search in seconds.
    public let runtime: TimeInterval
    /// Human-readable summary of the route.
    public let explanation: String
    /// Turn-by-turn navigation instructions.
    public let turnInstructions: [TurnInstruction]
    /// Detailed route metrics including camera and segment counts.
    public let metrics: RouteMetrics

    /// Creates a search result with full route metrics.
    public init(
        path: [String],
        totalDistance: Double,
        totalTime: TimeInterval,
        nodesVisited: Int,
        runtime: TimeInterval,
        explanation: String,
        turnInstructions: [TurnInstruction] = [],
        metrics: RouteMetrics? = nil
    ) {
        self.path = path
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.nodesVisited = nodesVisited
        self.runtime = runtime
        self.explanation = explanation
        self.turnInstructions = turnInstructions
        self.metrics = metrics ?? RouteMetrics(
            totalDistance: totalDistance,
            totalTime: totalTime,
            searchCost: 0,
            speedCameraCount: 0,
            tollSegmentCount: 0,
            ferrySegmentCount: 0,
            tunnelSegmentCount: 0
        )
    }

    /// An empty result indicating no route was found.
    public static let empty = SearchResult(
        path: [],
        totalDistance: 0,
        totalTime: 0,
        nodesVisited: 0,
        runtime: 0,
        explanation: "No route found.",
        metrics: .empty
    )
}
