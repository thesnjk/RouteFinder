import Contracts
import DataLayer
import GraphCore
import PathfindingEngine
import RouteController
import Testing

private func defaultPreferences(algorithm: RoutingAlgorithm = .aStar) -> RoutingPreferences {
    RoutingPreferences(algorithm: algorithm)
}

@Test func routePlannerSingleLeg() async throws {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 5, cols: 5)
    let planner = RoutePlanner()
    let result = try await planner.calculateRoute(
        graph: graph,
        from: "N_0_0",
        to: "N_4_4",
        preferences: defaultPreferences()
    )
    #expect(!result.path.isEmpty)
    #expect(result.path.first == "N_0_0")
    #expect(result.path.last == "N_4_4")
}

@Test func routePlannerMultiStop() async throws {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 5, cols: 5)
    let planner = RoutePlanner()
    let result = try await planner.calculateMultiStopRoute(
        graph: graph,
        locations: ["N_0_0", "N_2_2", "N_4_4"],
        preferences: defaultPreferences()
    )
    #expect(!result.path.isEmpty)
    #expect(result.path.first == "N_0_0")
    #expect(result.path.last == "N_4_4")
}

@Test func routeChainerDedupesJunction() {
    let leg1 = SearchResult(
        path: ["A", "B", "C"],
        totalDistance: 100,
        totalTime: 60,
        nodesVisited: 3,
        runtime: 0.01,
        explanation: "Leg 1",
        metrics: RouteMetrics(
            totalDistance: 100,
            totalTime: 60,
            searchCost: 60,
            speedCameraCount: 0,
            tollSegmentCount: 0,
            ferrySegmentCount: 0,
            tunnelSegmentCount: 0
        )
    )
    let leg2 = SearchResult(
        path: ["C", "D", "E"],
        totalDistance: 200,
        totalTime: 120,
        nodesVisited: 3,
        runtime: 0.01,
        explanation: "Leg 2",
        metrics: RouteMetrics(
            totalDistance: 200,
            totalTime: 120,
            searchCost: 120,
            speedCameraCount: 1,
            tollSegmentCount: 0,
            ferrySegmentCount: 0,
            tunnelSegmentCount: 0
        )
    )
    let combined = RouteChainer.combine(legs: [leg1, leg2])
    #expect(combined.path == ["A", "B", "C", "D", "E"])
    #expect(combined.totalDistance == 300)
    #expect(combined.metrics.speedCameraCount == 1)
}

@Test func connectedNodeFinder() {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 3, cols: 3)
    let connected = ConnectedNodeFinder.findNearestConnectedNode(startingFrom: "N_1_1", graph: graph)
    #expect(connected == "N_1_1")
}

@Test func routePlannerGraphNotLoaded() async {
    let graph = Graph()
    let planner = RoutePlanner()
    do {
        _ = try await planner.calculateRoute(
            graph: graph,
            from: "A",
            to: "B",
            preferences: defaultPreferences()
        )
        Issue.record("Expected graphNotLoaded error")
    } catch let error as RoutingError {
        if case .graphNotLoaded = error {
            // expected
        } else {
            Issue.record("Wrong error: \(error)")
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
