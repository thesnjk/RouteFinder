import Contracts
import DataLayer
import Foundation
import RouteController
import Testing
@testable import UI

@MainActor
@Suite("RoutePlanningCoordinator")
struct RoutePlanningCoordinatorTests {
    @Test func searchResultUsesHGVLabelAndDistance() {
        let response = ExternalRouteResponse(
            coordinates: [
                Coordinate(latitude: 52.6, longitude: 1.3),
                Coordinate(latitude: 52.7, longitude: 1.4),
            ],
            distanceMeters: 12_500,
            durationSeconds: 900,
            maneuvers: [],
            speedLimitSource: nil
        )
        let preferences = RoutingPreferences(
            isHGVMode: true,
            vehicle: .ukArtic
        )
        let instructions = RoutePlanningCoordinator.heuristicTurnInstructions(from: response)
        let result = RoutePlanningCoordinator.searchResult(
            from: response,
            preferences: preferences,
            turnInstructions: instructions
        )
        #expect(result.totalDistance == 12_500)
        #expect(result.totalTime == 900)
        #expect(result.explanation.contains("HGV"))
        #expect(result.explanation.contains("12.5 km"))
        #expect(result.path == ["external-ors"])
    }

    @Test func lezAvoidPolygonsNilWhenAvoidDisabled() {
        let polygons = RoutePlanningCoordinator.lezAvoidPolygons(
            emissionClass: .euro6,
            avoidEnabled: false,
            origin: RoutingCoordinate(latitude: 51.5, longitude: -0.12),
            destination: RoutingCoordinate(latitude: 51.52, longitude: -0.1)
        )
        #expect(polygons == nil)
    }

    @Test func presentRouteErrorClearsHostResult() {
        let host = MockRoutePlanningHost()
        host.result = SearchResult(
            path: ["x"],
            totalDistance: 1,
            totalTime: 1,
            nodesVisited: 1,
            runtime: 0,
            explanation: "x",
            turnInstructions: [],
            metrics: RouteMetrics(
                totalDistance: 1,
                totalTime: 1,
                searchCost: 1,
                speedCameraCount: 0,
                tollSegmentCount: 0,
                ferrySegmentCount: 0,
                tunnelSegmentCount: 0
            )
        )
        let coordinator = RoutePlanningCoordinator(host: host)
        coordinator.presentRouteError(
            OfflineGraphStoreError.noTilesAvailable,
            preferences: RoutingPreferences(isHGVMode: true, vehicle: .ukArtic)
        )
        #expect(host.result == nil)
        #expect(host.routeFailure?.kind == .coverage)
        #expect(host.didClearGeometry)
        #expect(host.routeDetailCollapseTick == 1)
    }
}

@MainActor
private final class MockRoutePlanningHost: RoutePlanningHost {
    var isCalculating = false
    var errorMessage: String?
    var routeFailure: RouteFailurePresentation?
    var routeDetailCollapseTick: Int = 0
    var result: SearchResult?
    var trafficRerouteAvailable = false
    var isEvaluatingTrafficReroute = false
    var pendingTrafficAlternate: ExternalRouteResponse?
    var didClearGeometry = false
    var calculateRouteCallCount = 0

    func clearRouteGeometry() {
        didClearGeometry = true
    }

    func applyLaneGuidanceEnrichment(_ instructions: [TurnInstruction]) {}

    func calculateRoute() async {
        calculateRouteCallCount += 1
    }
}
