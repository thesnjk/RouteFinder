import Contracts
import Foundation
import RouteController
import Testing

/// Counts Overpass fetch calls without hitting the network.
private actor CountingLaneGuidanceFetcher: LaneGuidanceFetching {
    private(set) var fetchCount = 0

    func fetchLaneGuidance(
        near coordinate: RoutingCoordinate,
        searchRadiusMeters: Double,
        maneuver: TurnManeuver?
    ) async throws -> LaneGuidance? {
        fetchCount += 1
        return nil
    }

    func count() -> Int { fetchCount }
}

@Test func laneGuidanceEnricherCapsOverpassFetchesAtDefaultMax() async {
    let fetcher = CountingLaneGuidanceFetcher()
    var instructions: [TurnInstruction] = []
    instructions.reserveCapacity(30)
    for index in 0..<30 {
        instructions.append(
            TurnInstruction(
                maneuver: index == 0 ? .depart : (index == 29 ? .arrive : .left),
                roadName: "Road \(index)",
                distance: 500,
                bearing: Double(index * 12)
            )
        )
    }
    // Polyline long enough for cumulative distance along instructions.
    var coordinates: [Coordinate] = []
    for i in 0...40 {
        coordinates.append(Coordinate(latitude: 52.6 + Double(i) * 0.001, longitude: 1.3))
    }

    _ = await LaneGuidanceEnricher.enrichWithOverpass(
        instructions: instructions,
        coordinates: coordinates,
        options: .default,
        client: fetcher
    )

    let count = await fetcher.count()
    #expect(count <= LaneGuidanceEnrichmentOptions.default.maxOverpassManeuvers)
    #expect(count == 12)
}

@Test func laneGuidanceEnricherRespectsZeroOverpassCap() async {
    let fetcher = CountingLaneGuidanceFetcher()
    let instructions = (0..<10).map { index in
        TurnInstruction(
            maneuver: .right,
            roadName: "R\(index)",
            distance: 200,
            bearing: 90
        )
    }
    let coordinates = [
        Coordinate(latitude: 52.63, longitude: 1.30),
        Coordinate(latitude: 52.64, longitude: 1.31),
        Coordinate(latitude: 52.65, longitude: 1.32),
    ]

    _ = await LaneGuidanceEnricher.enrichWithOverpass(
        instructions: instructions,
        coordinates: coordinates,
        options: LaneGuidanceEnrichmentOptions(maxOverpassManeuvers: 0, queryOverpass: true),
        client: fetcher
    )

    #expect(await fetcher.count() == 0)
}
