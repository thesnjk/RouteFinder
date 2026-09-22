import Contracts
import CoreLocation
import DataLayer
import Foundation
import MapLibreUI
import NavigationCore
import RouteController
import Testing
@testable import UI

@MainActor
@Suite("RouteSimulationCoordinator")
struct RouteSimulationCoordinatorTests {
    @Test func cappedPhysicsETALimitsKineticToThreeTimesWeb() {
        let host = MockRouteSimulationHost()
        let coordinator = RouteSimulationCoordinator(host: host)
        let capped = coordinator.cappedPhysicsETA(kinetic: 10_000, webETA: 1_000)
        #expect(capped == 3_000)
    }

    @Test func cappedPhysicsETAReturnsKineticWhenWebETAZero() {
        let host = MockRouteSimulationHost()
        let coordinator = RouteSimulationCoordinator(host: host)
        let capped = coordinator.cappedPhysicsETA(kinetic: 500, webETA: 0)
        #expect(capped == 500)
    }

    @Test func setSimulationSpeedUpdatesEngineMultiplier() {
        let host = MockRouteSimulationHost()
        let coordinator = RouteSimulationCoordinator(host: host)
        coordinator.setSimulationSpeed(.x10)
        #expect(host.simulationEngine.simulationSpeedMultiplier == 10)
    }

    @Test func cancelPhysicsWorkClearsETAFlags() {
        let host = MockRouteSimulationHost()
        host.physicsPredictedDurationSeconds = 100
        host.journeyPhysicsETASeconds = 100
        host.isEstimatingPhysicsDuration = true
        host.isRehearsingRoute = true
        host.latestKineticAdvisory = KineticAdvisory(
            kind: .brakeFade,
            spokenText: "Brake fade risk",
            priority: 1
        )
        let coordinator = RouteSimulationCoordinator(host: host)
        coordinator.cancelPhysicsWork()
        #expect(host.physicsPredictedDurationSeconds == nil)
        #expect(host.journeyPhysicsETASeconds == nil)
        #expect(host.isEstimatingPhysicsDuration == false)
        #expect(host.isRehearsingRoute == false)
        #expect(host.latestKineticAdvisory == nil)
    }

    @Test func findBreakNowNoopsWhenDisabled() async {
        let host = MockRouteSimulationHost()
        host.breakNowQuickActionEnabled = false
        host.upcomingLaybys = [
            LaybyStop(
                id: "l1",
                coordinate: Coordinate(latitude: 52, longitude: 0),
                label: "Layby"
            )
        ]
        let coordinator = RouteSimulationCoordinator(host: host)
        await coordinator.findBreakNow()
        #expect(host.rankBreakNowCallCount == 0)
    }
}

@MainActor
@Suite("HosAdvisoryCoordinator")
struct HosAdvisoryCoordinatorTests {
    @Test func refreshHosSnapshotClearsWhenDisabled() async {
        let host = MockHosAdvisoryHost()
        host.hosEnabled = false
        host.hosSnapshot = HosClockSnapshot(
            mode: .offDuty,
            remainingContinuousDriveSeconds: 100,
            remainingDailyDriveSeconds: 200,
            remainingWeeklyDriveSeconds: 300
        )
        let coordinator = HosAdvisoryCoordinator(host: host)
        await coordinator.refreshHosSnapshot()
        #expect(host.hosSnapshot == nil)
        #expect(host.canIDriveStatus != nil)
    }

    @Test func hosPathDurationsEmptyWithoutRouteMetrics() {
        let host = MockHosAdvisoryHost()
        host.result = nil
        host.physicsPredictedDurationSeconds = nil
        let coordinator = HosAdvisoryCoordinator(host: host)
        #expect(coordinator.hosPathDurationsSeconds().isEmpty)
    }

    @Test func hosPathDurationsSplitsByCumulativeLengths() {
        let host = MockHosAdvisoryHost()
        host.physicsPredictedDurationSeconds = 100
        host.routeCoordinates = [
            CLLocationCoordinate2D(latitude: 52, longitude: 0),
            CLLocationCoordinate2D(latitude: 52.1, longitude: 0.1),
            CLLocationCoordinate2D(latitude: 52.2, longitude: 0.2),
        ]
        host.routeCumulativeLengths = [0, 25, 100]
        let coordinator = HosAdvisoryCoordinator(host: host)
        let durations = coordinator.hosPathDurationsSeconds()
        #expect(durations.count == 2)
        #expect(abs(durations[0] - 25) < 0.01)
        #expect(abs(durations[1] - 75) < 0.01)
    }

    @Test func clearImportedTachoSummaryClearsHost() async {
        let host = MockHosAdvisoryHost()
        host.tachoSummary = TachoCardSummary(
            remainingContinuousDriveSeconds: 100,
            remainingDailyDriveSeconds: 200,
            remainingWeeklyDriveSeconds: 300,
            sourceFileName: "test.json"
        )
        let coordinator = HosAdvisoryCoordinator(host: host)
        await coordinator.clearImportedTachoSummary()
        #expect(host.tachoSummary == nil)
        #expect(host.canIDriveStatus != nil)
    }
}

@MainActor
private final class MockRouteSimulationHost: RouteSimulationHost {
    let simulationEngine = RouteSimulationEngine(tomTomAPIKey: "")
    let navigationCoordinator = NavigationCoordinator { VehicleMapDimensions(lengthMeters: 12, widthMeters: 2.5) }
    var mapBridge: MapViewControllerBridge?
    var environmentalContext = EnvironmentalContext.dry
    var result: SearchResult?
    var physicsPredictedDurationSeconds: TimeInterval?
    var journeyPhysicsETASeconds: TimeInterval?
    var journeyETAAnchorDate: Date?
    var isEstimatingPhysicsDuration = false
    var isRehearsingRoute = false
    var latestKineticAdvisory: KineticAdvisory?
    var simulationCameraZoom: Double = 15
    var simulationZoomLockedByUser = false
    var laybyVoiceAlertsEnabled = false
    var laybyAdvisory: LaybyAdvisory?
    var breakNowQuickActionEnabled = true
    var upcomingLaybys: [LaybyStop] = []
    var hosEnabled = false
    var hosSnapshot: HosClockSnapshot?
    let hosClock = EU561HosClock(alertBus: InMemoryDriverAlertBus())
    var activeDispatchTripId: UUID?
    var tripBriefShareText: String?
    var rankBreakNowCallCount = 0

    func laybyPredictionInput(currentArcLengthMeters: Double, speedMps: Double) -> LaybyPredictionInput {
        LaybyPredictionInput(
            candidates: upcomingLaybys,
            currentArcLengthMeters: currentArcLengthMeters,
            speedMps: speedMps
        )
    }

    func rankBreakNowLayby(
        currentArcLengthMeters: Double,
        speedMps: Double,
        predictionInput: LaybyPredictionInput
    ) async -> LaybyAdvisory? {
        rankBreakNowCallCount += 1
        return nil
    }

    func focusMapOnLayby(_ advisory: LaybyAdvisory) {}
    func tripBriefContext() -> TripBriefContext { TripBriefContext() }
    func publishRehearsedDispatchSnapshot() async {}
    func refreshLaybyAdvisory() async {}
    func refreshHazardAheadAnnouncement() {}
    func sampleTomTomHazardAheadIfNeeded() {}
    func refreshActiveRoadworksAhead() {}
    func refreshPredictiveRiskAdvisories() async {}
    func refreshActiveLaneGuidance() {}
#if os(iOS)
    func speakKineticAdvisory(_ advisory: KineticAdvisory) {}
    func speakLaybyAdvisory(_ prompt: String, laybyId: String) {}
#endif
}

@MainActor
private final class MockHosAdvisoryHost: HosAdvisoryHost {
    var hosEnabled = true
    var hosSnapshot: HosClockSnapshot?
    var hosForecast: HosRestInsertionResult?
    var tachoSummary: TachoCardSummary?
    var canIDriveStatus: CanIDriveStatus?
    var tachoImportError: String?
    let hosClock = EU561HosClock(alertBus: InMemoryDriverAlertBus())
    let tachoImporter = DDDImporter()
    var errorMessage: String?
    var result: SearchResult?
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var routeCumulativeLengths: [Double] = []
    var physicsPredictedDurationSeconds: TimeInterval?
    var upcomingTruckPois: [TruckPoi] = []
    var vehicleWeight = "44"
    var tripBriefRefreshCount = 0

    func refreshTripBriefShareText() {
        tripBriefRefreshCount += 1
    }
}
