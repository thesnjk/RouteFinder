import Contracts
import Foundation
import os
@testable import RouteController
import Testing

private final class MockLaneGuidanceClient: LaneGuidanceFetching, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private(set) var fetchCount = 0
    private(set) var peakInFlight = 0
    private var inFlight = 0
    private(set) var lastManeuver: TurnManeuver?
    var handler: @Sendable (RoutingCoordinate, TurnManeuver?) async throws -> LaneGuidance? = { _, _ in nil }

    func fetchLaneGuidance(
        near coordinate: RoutingCoordinate,
        searchRadiusMeters: Double,
        maneuver: TurnManeuver?
    ) async throws -> LaneGuidance? {
        let currentHandler = lock.withLock {
            fetchCount += 1
            inFlight += 1
            peakInFlight = max(peakInFlight, inFlight)
            lastManeuver = maneuver
            return handler
        }

        defer {
            lock.withLock {
                inFlight -= 1
            }
        }

        return try await currentHandler(coordinate, maneuver)
    }

    var callCount: Int {
        lock.withLock { fetchCount }
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
        client.handler = { _, _ in
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
        client.handler = { _, _ in
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

    @Test func enrichWithOverpassSkipsNetworkWhenDisabled() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _, _ in
            LaneGuidance(lanes: [.left], recommendedIndices: [0])
        }
        let instructions = sampleInstructions(count: 4)
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]

        _ = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: instructions,
            coordinates: coordinates,
            options: LaneGuidanceEnrichmentOptions(queryOverpass: false),
            client: client
        )

        #expect(client.callCount == 0)
    }

    @Test func enrichWithOverpassRespectsDistanceCap() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _, _ in
            LaneGuidance(lanes: [.straight], recommendedIndices: [0])
        }
        let instructions = [
            TurnInstruction(maneuver: .depart, roadName: "A", distance: 1_000, bearing: 0),
            TurnInstruction(maneuver: .left, roadName: "B", distance: 2_000, bearing: 90),
            TurnInstruction(maneuver: .right, roadName: "C", distance: 2_000, bearing: 180),
            TurnInstruction(maneuver: .arrive, roadName: "D", distance: 0, bearing: 0),
        ]
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]

        _ = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: instructions,
            coordinates: coordinates,
            options: LaneGuidanceEnrichmentOptions(
                maxOverpassManeuvers: 8,
                maxOverpassDistanceMeters: 1_500,
                queryOverpass: true
            ),
            client: client
        )

        #expect(client.callCount == 1)
    }

    @Test func enrichWithOverpassLimitsConcurrentRequests() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _, _ in
            try? await Task.sleep(for: .milliseconds(50))
            return LaneGuidance(lanes: [.left], recommendedIndices: [0])
        }
        let instructions = [
            TurnInstruction(maneuver: .depart, roadName: "A", distance: 500, bearing: 0),
            TurnInstruction(maneuver: .left, roadName: "B", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .left, roadName: "C", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .left, roadName: "D", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .left, roadName: "E", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .left, roadName: "F", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .left, roadName: "G", distance: 500, bearing: 90),
            TurnInstruction(maneuver: .arrive, roadName: "H", distance: 0, bearing: 0),
        ]
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]

        _ = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: instructions,
            coordinates: coordinates,
            options: LaneGuidanceEnrichmentOptions(
                maxOverpassManeuvers: 6,
                maxConcurrentOverpassRequests: 3
            ),
            client: client
        )

        #expect(client.callCount == 6)
        #expect(client.peakInFlight <= 3)
    }

    @Test func enrichWithOverpassForwardsManeuverToClient() async {
        let client = MockLaneGuidanceClient()
        client.handler = { _, _ in nil }
        let instructions = [
            TurnInstruction(maneuver: .right, roadName: "A", distance: 500, bearing: 90),
        ]
        let coordinates = [
            Coordinate(latitude: 52.63, longitude: 1.29),
            Coordinate(latitude: 52.64, longitude: 1.30),
        ]

        _ = await LaneGuidanceEnricher.enrichWithOverpass(
            instructions: instructions,
            coordinates: coordinates,
            options: LaneGuidanceEnrichmentOptions(maxOverpassManeuvers: 1),
            client: client
        )

        #expect(client.lastManeuver == .right)
    }
}

@Suite(.serialized)
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

    @Test func cacheReparsesWithManeuverContext() async {
        let cache = OverpassLaneGuidanceCache()
        cache.clear()

        let mockSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockOverpassURLProtocol.self]
            return config
        }())
        MockOverpassURLProtocol.handler = { _ in
            let json = """
            {"elements":[{"tags":{"turn:lanes":"left;through|through|through;right"}}]}
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

        let leftGuidance = try? await overpassClient.fetchLaneGuidance(
            near: coordinate,
            maneuver: TurnManeuver.left
        )
        let straightGuidance = try? await overpassClient.fetchLaneGuidance(
            near: coordinate,
            maneuver: TurnManeuver.straight
        )

        #expect(leftGuidance?.recommendedIndices == [0])
        #expect(straightGuidance?.recommendedIndices == [0, 1, 2])
        cache.clear()
    }
}

private final class MockOverpassURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Data, URLResponse))?

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
