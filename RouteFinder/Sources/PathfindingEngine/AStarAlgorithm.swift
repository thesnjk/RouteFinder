import Contracts
import CostModel
import GraphCore
import Foundation

/// A* search algorithm with Haversine heuristic.
public struct AStarAlgorithm: PathfindingAlgorithm {
    private let costModel: any CostModelProtocol

    /// Creates an A* algorithm with the given cost model.
    public init(costModel: any CostModelProtocol = CostModel()) {
        self.costModel = costModel
    }

    public var name: String { "A*" }

    public func findRoute(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        preferences: RoutingPreferences
    ) async -> SearchResult {
        let startTime = Date()

        guard let endNode = graph.node(id: endID) else { return SearchResult.empty }
        guard graph.node(id: startID) != nil else { return SearchResult.empty }

        let maxSpeedMps = CostConstants.heuristicMaxSpeedKmh * 1000 / 3600

        let heuristic: (String) -> Double = { nodeID in
            guard let node = graph.node(id: nodeID) else { return 0 }
            return Haversine.heuristic(from: node, to: endNode) / maxSpeedMps
        }

        let result = GraphSearcher.search(
            graph: graph,
            from: startID,
            to: endID,
            preferences: preferences,
            costModel: costModel,
            heuristic: heuristic
        )

        let runtime = Date().timeIntervalSince(startTime)

        guard let result else {
            return SearchResult(
                path: [],
                totalDistance: 0,
                totalTime: 0,
                nodesVisited: 0,
                runtime: runtime,
                explanation: "No route found via A*."
            )
        }

        return PathReconstructor.buildResult(
            path: result.path,
            cameFrom: result.cameFrom,
            nodesVisited: result.nodesVisited,
            runtime: runtime,
            graph: graph,
            algorithmName: name,
            preferences: preferences,
            searchCost: result.searchCost
        )
    }
}
