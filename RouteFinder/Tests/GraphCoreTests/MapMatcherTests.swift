import Contracts
import GraphCore
import Testing

@Test func mapMatcherProjectsOntoSegment() {
    let start = Coordinate(latitude: 52.63, longitude: 1.29)
    let end = Coordinate(latitude: 52.63, longitude: 1.30)
    let point = Coordinate(latitude: 52.631, longitude: 1.295)

    let projection = MapMatcher.projectPoint(point, ontoSegmentFrom: start, to: end)
    #expect(projection != nil)
    #expect(projection!.distanceMeters < 2000)
}

@Test func mapMatcherFindsNearestSegment() {
    let graph = Graph()
    graph.addNode(Node(id: "A", latitude: 52.63, longitude: 1.29))
    graph.addNode(Node(id: "B", latitude: 52.63, longitude: 1.30))
    graph.addEdge(Edge(from: "A", to: "B", distance: 700, speed: 50, roadName: "Test Road"))
    graph.buildSpatialIndex()

    let click = Coordinate(latitude: 52.6305, longitude: 1.295)
    let segments = graph.roadSegments(near: click, radiusMeters: 600)
    #expect(!segments.isEmpty)

    let match = graph.matchToRoad(to: click, maxDistanceMeters: 500)
    #expect(match != nil)
    #expect(match!.snapDistanceMeters <= 500)
}
