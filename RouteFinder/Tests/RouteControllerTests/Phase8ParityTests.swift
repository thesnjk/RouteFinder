import Contracts
import Foundation
import GraphCore
import RouteController
import Testing

@Test func ukTollCatalogHasMajorCrossings() {
    #expect(UKTollAdvisoryCatalog.all.count >= 14)
    #expect(UKTollAdvisoryCatalog.advisory(id: "dartford-crossing") != nil)
    #expect(UKTollAdvisoryCatalog.advisory(id: "m6-toll") != nil)
    #expect(UKTollAdvisoryCatalog.advisory(id: "mersey-tunnels-queensway") != nil)
    #expect(UKTollAdvisoryCatalog.advisory(id: "mersey-tunnels-kingsway") != nil)
}

@Test func routingPreferencesAvoidTollsDefaultsOffForCommitHonesty() {
    let prefs = RoutingPreferences()
    #expect(prefs.avoidTolls == false)
}

@Test func ukTollCatalogSeedsIndicativeGBPForTolledCrossings() {
    let dartford = UKTollAdvisoryCatalog.advisory(id: "dartford-crossing")
    let m6 = UKTollAdvisoryCatalog.advisory(id: "m6-toll")
    let tyne = UKTollAdvisoryCatalog.advisory(id: "tyne-tunnel")
    let queensway = UKTollAdvisoryCatalog.advisory(id: "mersey-tunnels-queensway")
    let kingsway = UKTollAdvisoryCatalog.advisory(id: "mersey-tunnels-kingsway")
    let severn = UKTollAdvisoryCatalog.advisory(id: "severn-crossings")
    #expect(dartford?.indicativeCostGBP == 8.40)
    #expect(m6?.indicativeCostGBP == 20.20)
    #expect(tyne?.indicativeCostGBP == 5.20)
    #expect(queensway?.indicativeCostGBP == 4.80)
    #expect(kingsway?.indicativeCostGBP == 4.80)
    #expect(severn?.indicativeCostGBP == nil)
}

@Test func ukTollIndicativeRouteTotalSumsMatchedCosts() {
    let dartford = UKTollAdvisoryCatalog.advisory(id: "dartford-crossing")!
    let m6 = UKTollAdvisoryCatalog.advisory(id: "m6-toll")!
    let severn = UKTollAdvisoryCatalog.advisory(id: "severn-crossings")!
    let total = UKTollAdvisory.indicativeRouteTotalGBP(advisories: [dartford, m6, severn])
    #expect(total == (dartford.indicativeCostGBP! + m6.indicativeCostGBP!))
    #expect(UKTollAdvisory.indicativeRouteTotalLabel(advisories: [dartford, m6]) != nil)
    #expect(UKTollAdvisory.indicativeRouteTotalGBP(advisories: [severn]) == nil)
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

/// Desk preview parity: Dartford + M6 corridor yields both hits and ~£19 indicative total.
@Test func tollMatcherHitsDartfordAndM6WithIndicativeTotal() {
    guard let dartford = UKTollAdvisoryCatalog.advisory(id: "dartford-crossing"),
          let m6 = UKTollAdvisoryCatalog.advisory(id: "m6-toll") else {
        Issue.record("Missing Dartford or M6 catalog entry")
        return
    }
    let polyline = [
        Coordinate(latitude: dartford.latitude, longitude: dartford.longitude),
        Coordinate(latitude: 52.0, longitude: -0.5),
        Coordinate(latitude: m6.latitude, longitude: m6.longitude),
    ]
    let hits = TollAdvisoryAlongRouteMatcher.advisories(along: polyline)
    #expect(hits.map(\.id).contains("dartford-crossing"))
    #expect(hits.map(\.id).contains("m6-toll"))
    #expect(hits.first?.id == "dartford-crossing")
    #expect(UKTollAdvisory.indicativeRouteTotalGBP(advisories: hits) == 19)
    #expect(TollAdvisoryAlongRouteMatcher.advisories(along: []).isEmpty)
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

@Test func overpassPrefersBothWaysOverBackward() {
    let tags: [[String: String]] = [
        ["turn:lanes:backward": "left|through"],
        ["turn:lanes:both_ways": "left|through|right"],
    ]
    let best = OverpassLaneGuidanceClient.richestTurnLanesTag(from: tags)
    #expect(best == "left|through|right")
}

@Test func laneGuidanceSourceDistinguishesHeuristic() {
    let heuristic = TurnLanesParser.heuristic(for: .left)
    #expect(heuristic.source == .heuristic)
    let osm = TurnLanesParser.parse(turnLanes: "left|through|right", forManeuver: .left)
    #expect(osm?.source == .osm)
}
