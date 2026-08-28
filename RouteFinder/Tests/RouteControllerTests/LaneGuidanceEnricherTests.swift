import Contracts
import Foundation
import RouteController
import Testing

private final class MockLaneGuidanceClient: LaneGuidanceFetching, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var fetchCount = 0
    var handler: @Sendable (RoutingCoordinate) async throws -> LaneGuidance? = { _ in nil }

    func fetchLaneGuidance(
        near coordinate: RoutingCoordinate,
        searchRadiusMeters: Double
    ) async throws -> LaneGuidance? {
        lock.lock()
        fetchCount += 1
        let currentHandler = handler
        lock.unlock()
        return try await currentHandler(coordinate)
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return fetchCount
    }
}

struct LaneGuidanceEnricherTests {
    private func sampleInstructions(count: Int) -> [TurnInstruction] {
        (0..<count).map { index in
            TurnInstruction(
                maneuver: index == 0 ? .depart : (index == count - 1 ? .arrive : .left),
                roadName: "Road \(index)",
                distance: 1_000,
                bearing: 90
            )
        }
    }

    @Test func enrichWithHeuristicsIsSynchronous() {
        let instructions = sampleInstructions(count: 4)
        let enriched = LaneGuidanceEnricher.enrichWithHeuristics(instructions: instructions)
        #expect(enriched.count == 4)
        #expect(enriched[1].laneGuidance != nil)
        #expect(enriched[0].laneGuidance == nil)
        #expect(enriched[3].laneGuidance == nil)
    }

    @Test func enrichWithOverpassRespectsManeuverCap() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _ in
            LaneGuidance(lanes: [.left, .straight], recommendedIndices: [0])
        }
        let instructions = sampleInstructions(count: 12)
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]
        let options = LaneGuidanceEnrichmentOptions(
            maxOverpassManeuvers: 3,
            maxOverpassDistanceMeters: 50_000,
            queryOverpass: true
        )

        _ = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: instructions,
            coordinates: coordinates,
            options: options,
            client: client
        )

        #expect(client.callCount == 3)
    }

    @Test func enrichWithOverpassUpgradesHeuristicLanes() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _ in
            LaneGuidance(lanes: [.straight, .right], recommendedIndices: [1])
        }
        let base = TurnInstruction(
            maneuver: .right,
            roadName: "A47",
            distance: 500,
            bearing: 180,
            laneGuidance: TurnLanesParser.heuristic(for: .right)
        )
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]

        let enriched = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: [base],
            coordinates: coordinates,
            options: LaneGuidanceEnrichmentOptions(maxOverpassManeuvers: 1),
            client: client
        )

        #expect(enriched.first?.laneGuidance?.lanes == [.straight, .right])
        #expect(client.callCount == 1)
    }
}

struct OverpassLaneGuidanceCacheTests {
    @Test func cacheDeduplicatesCoordinateGrid() async {
        let cache = OverpassLaneGuidanceCache()
        cache.clear()
        var fetchCount = 0

        let mockSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockOverpassURLProtocol.self]
            return config
        }())
        MockOverpassURLProtocol.handler = { _ in
            fetchCount += 1
            let json = """
            {"elements":[{"tags":{"turn:lanes":"left|through|right"}}]}
            """
            let response = HTTPURLResponse(
                url: URL(string: "https://overpass-api.de/api/interpreter")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (json.data(using: .utf8)!, response)
        }

        let overpassClient = OverpassLaneGuidanceClient(session: mockSession, cache: cache)
        let coordinate = RoutingCoordinate(latitude: 52.63001, longitude: 1.29701)

        _ = try? await overpassClient.fetchLaneGuidance(near: coordinate)
        _ = try? await overpassClient.fetchLaneGuidance(
            near: RoutingCoordinate(latitude: 52.63002, longitude: 1.29702)
        )

        #expect(fetchCount == 1)
        cache.clear()
    }
}

private final class MockOverpassURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) -> (Data, URLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let (data, response) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
