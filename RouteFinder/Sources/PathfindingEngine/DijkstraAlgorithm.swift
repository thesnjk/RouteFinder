import Contracts
import CostModel
import Foundation

/// Dijkstra's shortest path algorithm using a binary heap priority queue.
public struct DijkstraAlgorithm: PathfindingAlgorithm {
    private let costModel: any CostModelProtocol

    /// Creates a Dijkstra algorithm with the given cost model.
    public init(costModel: any CostModelProtocol = CostModel()) {
        self.costModel = costModel
    }

    public var name: String { "Dijkstra" }

    public func findRoute(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        preferences: RoutingPreferences
    ) async -> SearchResult {
        let startTime = Date()

        guard graph.node(id: startID) != nil else { return SearchResult.empty }
        guard graph.node(id: endID) != nil else { return SearchResult.empty }

        let result = GraphSearcher.search(
            graph: graph,
            from: startID,
            to: endID,
            preferences: preferences,
            costModel: costModel,
            heuristic: nil
        )

        let runtime = Date().timeIntervalSince(startTime)

        guard let result else {
            return SearchResult(
                path: [],
                totalDistance: 0,
                totalTime: 0,
                nodesVisited: 0,
                runtime: runtime,
                explanation: "No route found via Dijkstra."
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
