import Contracts
import CostModel
import Foundation
import PathfindingEngine

/// Orchestrates route calculation between the UI and pathfinding algorithms.
public struct RoutePlanner: Sendable {
    private let costModel: any CostModelProtocol
    private let externalClient: any ExternalRoutingClient

    /// Creates a route planner with the given cost model and optional external client.
    public init(
        costModel: any CostModelProtocol = CostModel(),
        externalClient: any ExternalRoutingClient = StubExternalRoutingClient()
    ) {
        self.costModel = costModel
        self.externalClient = externalClient
    }

    /// Creates the pathfinding algorithm for the given preferences.
    public func algorithm(for preferences: RoutingPreferences) -> any PathfindingAlgorithm {
        switch preferences.algorithm {
        case .aStar:
            return AStarAlgorithm(costModel: costModel)
        case .dijkstra:
            return DijkstraAlgorithm(costModel: costModel)
        }
    }

    /// Calculates a route via the configured external routing client and returns metrics plus geometry.
    public func calculateExternalRoute(request: ExternalRouteRequest) async throws -> (SearchResult, ExternalRouteResponse) {
        let response = try await externalClient.route(request: request)

        let turnInstructions: [TurnInstruction]
        if !response.maneuvers.isEmpty {
            turnInstructions = ORSTurnInstructionMapper.map(
                maneuvers: response.maneuvers,
                coordinates: response.coordinates
            )
        } else {
            turnInstructions = PolylineTurnInstructionGenerator.generate(
                coordinates: response.coordinates
            )
        }

        let distanceLabel = response.distanceMeters >= 1000
            ? String(format: "%.1f km", response.distanceMeters / 1000)
            : String(format: "%.0f m", response.distanceMeters)

        let profileLabel = request.preferences.isHGVMode ? "HGV" : "Car"
        let result = SearchResult(
            path: ["external-ors"],
            totalDistance: response.distanceMeters,
            totalTime: response.durationSeconds,
            nodesVisited: response.coordinates.count,
            runtime: 0,
            explanation: "HeiGIT \(profileLabel) route · \(distanceLabel)",
            turnInstructions: turnInstructions,
            metrics: RouteMetrics(
                totalDistance: response.distanceMeters,
                totalTime: response.durationSeconds,
                searchCost: response.durationSeconds,
                speedCameraCount: 0,
                tollSegmentCount: 0,
                ferrySegmentCount: 0,
                tunnelSegmentCount: 0
            )
        )

        return (result, response)
    }

    /// Calculates a single-leg route between two node IDs on a local graph.
    public func calculateRoute(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        preferences: RoutingPreferences
    ) async throws -> SearchResult {
        guard graph.nodeCount > 0 else {
            throw RoutingError.graphNotLoaded
        }

        guard !startID.isEmpty, !endID.isEmpty else {
            throw RoutingError.invalidInput("Start and end locations are required.")
        }

        guard graph.node(id: startID) != nil else {
            throw RoutingError.locationNotFound(startID)
        }
        guard graph.node(id: endID) != nil else {
            throw RoutingError.locationNotFound(endID)
        }

        let resolvedStart = ConnectedNodeFinder.findNearestConnectedNode(startingFrom: startID, graph: graph) ?? startID
        let resolvedEnd = ConnectedNodeFinder.findNearestConnectedNode(startingFrom: endID, graph: graph) ?? endID

        let algorithm = algorithm(for: preferences)
        let result = await algorithm.findRoute(
            graph: graph,
            from: resolvedStart,
            to: resolvedEnd,
            preferences: preferences
        )

        if result.path.isEmpty {
            if preferences.isHGVMode {
                throw RoutingError.noFeasibleRoute(constraint: "Vehicle exceeds bridge or road restrictions")
            }
            throw RoutingError.noFeasibleRoute(constraint: "No path exists between \(startID) and \(endID)")
        }

        return result
    }

    /// Calculates a multi-stop route through an ordered list of node IDs.
    public func calculateMultiStopRoute(
        graph: any GraphProtocol,
        locations: [String],
        preferences: RoutingPreferences
    ) async throws -> SearchResult {
        guard locations.count >= 2 else {
            throw RoutingError.invalidInput("At least two locations are required for routing.")
        }

        var legs: [SearchResult] = []
        for i in 0..<(locations.count - 1) {
            let leg = try await calculateRoute(
                graph: graph,
                from: locations[i],
                to: locations[i + 1],
                preferences: preferences
            )
            legs.append(leg)
        }

        return RouteChainer.combine(legs: legs)
    }
}
