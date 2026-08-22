import Contracts
import Foundation
import GraphCore
import Testing

@Test func haversineSamePointIsZero() {
    let coord = Coordinate(latitude: 52.6, longitude: 1.3)
    let dist = Haversine.distance(from: coord, to: coord)
    #expect(dist == 0)
}

@Test func haversineKnownDistance() {
    let norwich = Coordinate(latitude: 52.6309, longitude: 1.2974)
    let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
    let dist = Haversine.distance(from: norwich, to: london)
    #expect(dist > 150_000)
    #expect(dist < 170_000)
}

@Test func graphAddNodeAndEdge() {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.0, longitude: 1.0))
    graph.addNode(Node(id: "B", latitude: 52.01, longitude: 1.01))
    graph.addEdge(Edge(from: "A", to: "B", distance: 1000, speed: 50))

    #expect(graph.nodeCount == 2)
    #expect(graph.edgeCount == 2)
    #expect(graph.neighbors(of: "A").count == 1)
    #expect(graph.neighbors(of: "B").count == 1)
}

@Test func graphOneWayEdge() {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.0, longitude: 1.0))
    graph.addNode(Node(id: "B", latitude: 52.01, longitude: 1.01))
    graph.addEdge(Edge(from: "A", to: "B", distance: 1000, speed: 50, isOneWay: true))

    #expect(graph.edgeCount == 1)
    #expect(graph.neighbors(of: "A").count == 1)
    #expect(graph.neighbors(of: "B").count == 0)
}

@Test func findNearestNode() {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.630, longitude: 1.297))
    graph.addNode(Node(id: "B", latitude: 52.640, longitude: 1.307))
    graph.buildSpatialIndex()

    let nearest = graph.findNearestNode(to: Coordinate(latitude: 52.631, longitude: 1.298))
    #expect(nearest?.id == "A")
}

@Test func csvRoundTrip() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let nodesPath = tempDir.appendingPathComponent("test_nodes.csv").path
    let edgesPath = tempDir.appendingPathComponent("test_edges.csv").path

    let nodesCSV = """
    id,latitude,longitude,name
    A,52.0,1.0,Start
    B,52.01,1.01,End
    """
    let edgesCSV = """
    from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,max_height,max_weight,max_width,max_length,has_camera,is_one_way,road_name
    A,B,1000,50,primary,false,false,false,,,,,false,false,Main St
    """

    try nodesCSV.write(toFile: nodesPath, atomically: true, encoding: .utf8)
    try edgesCSV.write(toFile: edgesPath, atomically: true, encoding: .utf8)

    let graph = try await Graph.loadFromCSV(nodesPath: nodesPath, edgesPath: edgesPath)
    #expect(graph.nodeCount == 2)
    #expect(graph.edgeCount == 2)
    #expect(graph.node(id: "A")?.name == "Start")
}
