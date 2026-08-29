import Contracts
import DataLayer
import Testing
@testable import UI

@MainActor
@Suite("HazardNavigationCoordinator")
struct HazardNavigationCoordinatorTests {
    @Test func resetClearsHazardOverlay() {
        let state = HazardNavigationState()
        state.hazardOverlayJSON = "{\"type\":\"FeatureCollection\",\"features\":[{}]}"
        let coordinator = HazardNavigationCoordinator()
        coordinator.resetRouteHazardState(state: state)
        #expect(state.hazardOverlayJSON == HazardOverlayBuilder.emptyFeatureCollection)
        #expect(state.activeHazardAheadAnnouncement == nil)
    }

    @Test func recordCrowdReportPromotesOverlay() {
        let state = HazardNavigationState()
        let coordinator = HazardNavigationCoordinator()
        let report = CrowdReport(
            latitude: 52.6,
            longitude: 1.3,
            type: .traffic,
            reporterId: "driver-1"
        )
        let hazard = coordinator.recordCrowdReport(report, state: state)
        #expect(hazard != nil)
        #expect(state.crowdReports.count == 1)
        #expect(state.hazardOverlayJSON.contains("FeatureCollection"))
    }
}
