import Contracts
import CostModel
import DataLayer
import GraphCore
import PathfindingEngine
import Testing

@Test func dijkstraGridRoute() async {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 5, cols: 5)
    let result = await DijkstraAlgorithm().findRoute(
        graph: graph,
        from: "N_0_0",
        to: "N_4_4",
        preferences: RoutingPreferences(algorithm: .dijkstra)
    )

    #expect(!result.path.isEmpty)
    #expect(result.path.first == "N_0_0")
    #expect(result.path.last == "N_4_4")
    #expect(result.metrics.totalDistance > 0)
}

@Test func aStarGridRoute() async {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 5, cols: 5)
    let result = await AStarAlgorithm().findRoute(
        graph: graph,
        from: "N_0_0",
        to: "N_4_4",
        preferences: RoutingPreferences(algorithm: .aStar)
    )

    #expect(!result.path.isEmpty)
    #expect(result.path.first == "N_0_0")
    #expect(result.path.last == "N_4_4")
}

@Test func aStarVisitsFewerOrEqualNodes() async {
    let graph = SyntheticGraphBuilder.makeGrid(rows: 10, cols: 10)
    let prefs = RoutingPreferences()

    let dijkstra = await DijkstraAlgorithm().findRoute(
        graph: graph, from: "N_0_0", to: "N_9_9", preferences: RoutingPreferences(algorithm: .dijkstra)
    )
    let aStar = await AStarAlgorithm().findRoute(
        graph: graph, from: "N_0_0", to: "N_9_9", preferences: RoutingPreferences(algorithm: .aStar)
    )

    #expect(aStar.nodesVisited <= dijkstra.nodesVisited)
}

@Test func vehicleConstraintBlocksRoute() async {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.0, longitude: 1.0))
    graph.addNode(Node(id: "B", latitude: 52.01, longitude: 1.01))
    graph.addEdge(Edge(from: "A", to: "B", distance: 1000, speed: 50, maxHeight: 2.0))

    let result = await AStarAlgorithm().findRoute(
        graph: graph,
        from: "A",
        to: "B",
        preferences: RoutingPreferences(vehicle: VehicleProfile(height: 4.0))
    )

    #expect(result.path.isEmpty)
}

@Test func hurryModeAvoidsCameraEdge() async {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.60, longitude: 1.30))
    graph.addNode(Node(id: "B", latitude: 52.601, longitude: 1.301))
    graph.addNode(Node(id: "C", latitude: 52.602, longitude: 1.302))
    graph.addEdge(Edge(from: "A", to: "B", distance: 500, speed: 50, hasCamera: true, roadName: "Camera Rd"))
    graph.addEdge(Edge(from: "B", to: "C", distance: 500, speed: 50))
    graph.addEdge(Edge(from: "A", to: "C", distance: 1200, speed: 40, roadName: "Slow Rd"))

    let hurry = RoutingPreferences(hurryMode: true)
    let result = await AStarAlgorithm().findRoute(graph: graph, from: "A", to: "C", preferences: hurry)

    #expect(result.path == ["A", "C"])
}

@Test func hgvModeAvoidsResidentialWhenAlternativeExists() async {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.60, longitude: 1.30))
    graph.addNode(Node(id: "B", latitude: 52.601, longitude: 1.301))
    graph.addNode(Node(id: "C", latitude: 52.602, longitude: 1.302))
    graph.addEdge(Edge(from: "A", to: "B", distance: 500, speed: 30, roadType: .residential))
    graph.addEdge(Edge(from: "B", to: "C", distance: 500, speed: 30, roadType: .residential))
    graph.addEdge(Edge(from: "A", to: "C", distance: 1500, speed: 60, roadType: .trunk))

    let hgvPrefs = RoutingPreferences(
        isHGVMode: true,
        avoidResidential: true,
        vehicle: VehicleProfile(height: 4.0)
    )
    let result = await AStarAlgorithm().findRoute(graph: graph, from: "A", to: "C", preferences: hgvPrefs)
    #expect(result.path == ["A", "C"])
}

@Test func cameraCountInMetrics() async {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.60, longitude: 1.30))
    graph.addNode(Node(id: "B", latitude: 52.601, longitude: 1.301))
    graph.addEdge(Edge(from: "A", to: "B", distance: 500, speed: 50, hasCamera: true))

    let result = await AStarAlgorithm().findRoute(
        graph: graph, from: "A", to: "B", preferences: RoutingPreferences()
    )

    #expect(result.metrics.speedCameraCount == 1)
}
