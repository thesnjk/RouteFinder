import Contracts
import Foundation
import GraphCore
import RouteController
import Testing

@Test func ukTollCatalogHasMajorCrossings() {
    #expect(UKTollAdvisoryCatalog.all.count >= 12)
    #expect(UKTollAdvisoryCatalog.advisory(id: "dartford-crossing") != nil)
    #expect(UKTollAdvisoryCatalog.advisory(id: "m6-toll") != nil)
}

@Test func tollMatcherHitsDartfordPolyline() {
    guard let dartford = UKTollAdvisoryCatalog.advisory(id: "dartford-crossing") else {
        Issue.record("Missing Dartford catalog entry")
        return
    }
    let polyline = [
        Coordinate(latitude: dartford.latitude - 0.01, longitude: dartford.longitude - 0.01),
        Coordinate(latitude: dartford.latitude, longitude: dartford.longitude),
        Coordinate(latitude: dartford.latitude + 0.01, longitude: dartford.longitude + 0.01),
    ]
    let hits = TollAdvisoryAlongRouteMatcher.advisories(along: polyline)
    #expect(hits.contains(where: { $0.id == "dartford-crossing" }))
}

@Test func tollMatcherIgnoresDistantRoute() {
    let scotland = [
        Coordinate(latitude: 57.15, longitude: -2.10),
        Coordinate(latitude: 57.20, longitude: -2.05),
    ]
    let hits = TollAdvisoryAlongRouteMatcher.advisories(
        along: scotland,
        catalog: [UKTollAdvisoryCatalog.advisory(id: "dartford-crossing")!]
    )
    #expect(hits.isEmpty)
}

@Test func parkingPartnerLinksEncodeCoordinates() {
    let travis = ParkingPartnerLinks.travisURL(latitude: 52.63, longitude: 1.30, label: "Norwich")
    #expect(travis.absoluteString.contains("lat=52.63000"))
    #expect(travis.absoluteString.contains("lng=1.30000"))
    #expect(travis.absoluteString.contains("q=Norwich"))

    let snap = ParkingPartnerLinks.snapURL(latitude: 52.63, longitude: 1.30, label: "Depot")
    #expect(snap.absoluteString.contains("lat=52.63000"))
    #expect(snap.absoluteString.contains("lon=1.30000"))
}

@Test func overpassPrefersRichestTurnLanesTag() {
    let tags: [[String: String]] = [
        ["turn:lanes:forward": "through|right"],
        ["turn:lanes": "left|through|through|right"],
        ["destination:lanes": "A|B"],
    ]
    let best = OverpassLaneGuidanceClient.richestTurnLanesTag(from: tags)
    #expect(best == "left|through|through|right")
}

@Test func laneGuidanceSourceDistinguishesHeuristic() {
    let heuristic = TurnLanesParser.heuristic(for: .left)
    #expect(heuristic.source == .heuristic)
    let osm = TurnLanesParser.parse(turnLanes: "left|through|right", forManeuver: .left)
    #expect(osm?.source == .osm)
}
