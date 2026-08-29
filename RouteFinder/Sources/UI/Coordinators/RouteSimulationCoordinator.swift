import Contracts
import CoreLocation
import DataLayer
import Foundation
import MapLibreUI
import NavigationCore
import RouteController

/// Host surface for route-simulation orchestration owned by ``RouteViewModel``.
@MainActor
public protocol RouteSimulationHost: AnyObject {
    /// Physics simulation engine.
    var simulationEngine: RouteSimulationEngine { get }
    /// Navigation session coordinator.
    var navigationCoordinator: NavigationCoordinator { get }
    /// Map bridge for camera control (late-bound).
    var mapBridge: MapViewControllerBridge? { get }
    /// Active environmental context for physics.
    var environmentalContext: EnvironmentalContext { get }
    /// Latest search / route result.
    var result: SearchResult? { get }
    /// Physics-predicted duration in seconds.
    var physicsPredictedDurationSeconds: TimeInterval? { get set }
    /// Journey ETA derived from physics.
    var journeyPhysicsETASeconds: TimeInterval? { get set }
    /// Anchor date for journey ETA display.
    var journeyETAAnchorDate: Date? { get set }
    /// Whether physics duration estimation is running.
    var isEstimatingPhysicsDuration: Bool { get set }
    /// Whether a full route rehearsal is running.
    var isRehearsingRoute: Bool { get set }
    /// Latest kinetic advisory for HUD.
    var latestKineticAdvisory: KineticAdvisory? { get set }
    /// Simulation camera zoom level.
    var simulationCameraZoom: Double { get set }
    /// Whether the user locked simulation zoom.
    var simulationZoomLockedByUser: Bool { get set }
    /// Whether layby voice alerts are enabled.
    var laybyVoiceAlertsEnabled: Bool { get }
    /// Current layby advisory, if any.
    var laybyAdvisory: LaybyAdvisory? { get set }
    /// Whether Break Now quick action is enabled.
    var breakNowQuickActionEnabled: Bool { get }
    /// Upcoming layby stops along the route.
    var upcomingLaybys: [LaybyStop] { get }
    /// Whether advisory HOS is enabled.
    var hosEnabled: Bool { get }
    /// Latest HOS snapshot for HUD.
    var hosSnapshot: HosClockSnapshot? { get set }
    /// Advisory HOS clock.
    var hosClock: EU561HosClock { get }
    /// Active dispatch trip id when fleet is connected.
    var activeDispatchTripId: UUID? { get }
    /// Trip brief share text.
    var tripBriefShareText: String? { get set }

    /// Builds layby prediction input for the current route pose.
    func laybyPredictionInput(currentArcLengthMeters: Double, speedMps: Double) -> LaybyPredictionInput
    /// Ranks Break Now candidates via the layby advisor.
    func rankBreakNowLayby(
        currentArcLengthMeters: Double,
        speedMps: Double,
        predictionInput: LaybyPredictionInput
    ) async -> LaybyAdvisory?
    /// Centers the map on a layby.
    func focusMapOnLayby(_ advisory: LaybyAdvisory)
    /// Builds trip brief context for share text.
    func tripBriefContext() -> TripBriefContext
    /// Publishes a rehearsed fleet dispatch snapshot when a trip is active.
    func publishRehearsedDispatchSnapshot() async
    /// Refreshes layby advisory from current pose.
    func refreshLaybyAdvisory() async
    /// Refreshes hazard-ahead announcement.
    func refreshHazardAheadAnnouncement()
    /// Samples TomTom hazard ahead when configured.
    func sampleTomTomHazardAheadIfNeeded()
    /// Refreshes roadworks-ahead banner.
    func refreshActiveRoadworksAhead()
    /// Refreshes lane-keep popup.
    func refreshActiveLaneGuidance()
#if os(iOS)
    /// Speaks a kinetic advisory.
    func speakKineticAdvisory(_ advisory: KineticAdvisory)
    /// Speaks a layby voice alert.
    func speakLaybyAdvisory(_ prompt: String, laybyId: String)
#endif
}

/// Coordinates simulation callbacks, kinetic advisories, physics ETA, and Break Now.
@MainActor
public final class RouteSimulationCoordinator {
    private weak var host: RouteSimulationHost?
    private let kineticAdvisoryCoordinator = KineticAdvisoryCoordinator()
    private var physicsEstimateTask: Task<Void, Never>?
    private var rehearseTask: Task<Void, Never>?
    private var lastAnnouncedLaybyId: String?

    /// Creates a simulation coordinator bound to the given host.
    public init(host: RouteSimulationHost) {
        self.host = host
    }

    /// Wires simulation engine callbacks into navigation, kinetic, and ahead-of-route refresh.
    public func wireSimulationCallbacks() {
        guard let host else { return }
        host.navigationCoordinator.configureSimulationPoseSource { [weak host] in
            guard let host, let coordinate = host.simulationEngine.currentCoordinate else { return nil }
            return (
                coordinate: coordinate,
                bearing: host.simulationEngine.currentBearing,
                speedKmh: host.simulationEngine.currentSpeedKmh,
                arcLengthMeters: host.simulationEngine.currentArcLengthMeters
            )
        }
        host.simulationEngine.onDisplayFrameTick = { [weak host] in
            host?.navigationCoordinator.emitSimulationPose()
            Task { @MainActor in
                await host?.refreshLaybyAdvisory()
                host?.refreshHazardAheadAnnouncement()
                host?.sampleTomTomHazardAheadIfNeeded()
                host?.refreshActiveRoadworksAhead()
                host?.refreshActiveLaneGuidance()
            }
        }
        host.simulationEngine.onSimulationStarting = { [weak host] in
            try? await host?.navigationCoordinator.startSimulationNavigation()
        }
        host.simulationEngine.onSimulationStarted = { [weak host] in
            guard let host else { return }
            host.navigationCoordinator.emitSimulationPose()
            host.mapBridge?.trackingZoomLevel = host.simulationCameraZoom
            if host.simulationZoomLockedByUser {
                host.mapBridge?.setZoom(host.simulationCameraZoom)
            }
        }
        host.simulationEngine.onSimulationStopped = { [weak self, weak host] in
            host?.navigationCoordinator.stopNavigation()
            self?.resetKineticAdvisory()
            host?.latestKineticAdvisory = nil
        }
        host.simulationEngine.onUIStatePublished = { [weak self] uiState in
            self?.handleKineticUIState(uiState)
        }
        kineticAdvisoryCoordinator.onAdvisory = { [weak host] advisory in
            host?.latestKineticAdvisory = advisory
#if os(iOS)
            host?.speakKineticAdvisory(advisory)
#endif
        }
    }

    /// Sets simulation playback speed from the segmented control.
    public func setSimulationSpeed(_ multiplier: SpeedMultiplier) {
        host?.simulationEngine.simulationSpeedMultiplier = multiplier.rawValue
    }

    /// Re-applies the active environmental context to the running simulation.
    public func refreshSimulationEnvironment() {
        guard let host else { return }
        host.simulationEngine.updateEnvironmentalContext(host.environmentalContext)
    }

    /// Applies a user-chosen simulation camera zoom and keeps tracking from overriding it.
    public func setSimulationCameraZoom(_ zoom: Double) {
        guard let host else { return }
        let clamped = min(19, max(12, zoom))
        host.simulationCameraZoom = clamped
        host.simulationZoomLockedByUser = true
        host.mapBridge?.trackingZoomLevel = clamped
        host.mapBridge?.setZoom(clamped)
    }

    /// Ingests simulation UI state into the kinetic advisory coordinator.
    public func handleKineticUIState(_ uiState: SimulationUIState) {
        kineticAdvisoryCoordinator.ingest(uiState: uiState)
    }

    /// Clears kinetic advisory state.
    public func resetKineticAdvisory() {
        kineticAdvisoryCoordinator.reset()
        lastAnnouncedLaybyId = nil
    }

    /// Clears only the last announced layby id (e.g. when reloading candidates).
    public func clearLastAnnouncedLayby() {
        lastAnnouncedLaybyId = nil
    }

    /// Cancels in-flight physics estimate and rehearse work.
    public func cancelPhysicsWork() {
        physicsEstimateTask?.cancel()
        rehearseTask?.cancel()
        guard let host else { return }
        host.physicsPredictedDurationSeconds = nil
        host.journeyPhysicsETASeconds = nil
        host.journeyETAAnchorDate = nil
        host.isEstimatingPhysicsDuration = false
        host.isRehearsingRoute = false
        host.latestKineticAdvisory = nil
        resetKineticAdvisory()
    }

    /// Estimates physics duration for the active route and updates journey ETA.
    public func estimatePhysicsDuration(
        for searchResult: SearchResult,
        canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry
    ) {
        _ = canonical
        guard let host else { return }
        physicsEstimateTask?.cancel()
        host.physicsPredictedDurationSeconds = nil
        host.journeyPhysicsETASeconds = nil
        host.journeyETAAnchorDate = nil
        host.isEstimatingPhysicsDuration = true

        physicsEstimateTask = Task { @MainActor [weak self, weak host] in
            defer { host?.isEstimatingPhysicsDuration = false }
            guard let self, let host, !Task.isCancelled else { return }
            let estimate = await host.simulationEngine.estimatePhysicsDuration()
            guard !Task.isCancelled else { return }
            if let estimate {
                let capped = self.cappedPhysicsETA(
                    kinetic: estimate.kineticDurationSeconds,
                    webETA: searchResult.metrics.totalTime
                )
                host.physicsPredictedDurationSeconds = capped
                host.journeyPhysicsETASeconds = capped
                host.journeyETAAnchorDate = Date()
                host.navigationCoordinator.updateStaticTotalTime(capped)
            } else {
                host.journeyPhysicsETASeconds = nil
                host.journeyETAAnchorDate = nil
            }
        }
    }

    /// Caps kinetic ETA so it cannot exceed 3× the web ETA.
    public func cappedPhysicsETA(kinetic: TimeInterval, webETA: TimeInterval) -> TimeInterval {
        guard webETA > 0 else { return kinetic }
        return min(kinetic, webETA * 3)
    }

    /// Runs a full pre-trip physics rehearsal and publishes a shareable predictive trip brief.
    public func rehearseRoute() {
        guard let host, host.result != nil else { return }
        // Route coordinate count is validated by the host before calling when needed;
        // engine rehearse itself no-ops without a configured route.
        rehearseTask?.cancel()
        host.isRehearsingRoute = true
        rehearseTask = Task { @MainActor [weak self, weak host] in
            defer { host?.isRehearsingRoute = false }
            guard let self, let host, !Task.isCancelled else { return }
            let report = await host.simulationEngine.rehearseRoute()
            guard !Task.isCancelled else { return }
            if let report {
                let webETA = host.result?.metrics.totalTime ?? report.staticWebETASeconds
                let capped = self.cappedPhysicsETA(
                    kinetic: report.kineticPhysicsETASeconds,
                    webETA: webETA
                )
                host.physicsPredictedDurationSeconds = capped
                host.journeyPhysicsETASeconds = capped
                host.journeyETAAnchorDate = Date()
                host.navigationCoordinator.updateStaticTotalTime(capped)
                host.tripBriefShareText = TripBriefFormatter.plainText(from: host.tripBriefContext())
                if host.activeDispatchTripId != nil {
                    await host.publishRehearsedDispatchSnapshot()
                }
            }
        }
    }

    /// Announces the nearest layby once inside the alert distance (iOS).
    public func processLaybyVoiceAlertIfNeeded() {
#if os(iOS)
        guard let host, host.laybyVoiceAlertsEnabled, let advisory = host.laybyAdvisory else { return }
        let threshold = NavigationWorkspaceSettings.loadLaybyAlertDistanceMeters()
        guard LaybyAlertFormatter.shouldAnnounce(
            advisory: advisory,
            lastAnnouncedLaybyId: lastAnnouncedLaybyId,
            alertDistanceMeters: threshold
        ) else { return }
        host.speakLaybyAdvisory(
            LaybyAlertFormatter.spokenPrompt(for: advisory),
            laybyId: advisory.stop.id
        )
        lastAnnouncedLaybyId = advisory.stop.id
#endif
    }

    /// Break Now: rank nearest layby ahead and center the map on the top candidate.
    public func findBreakNow() async {
        guard let host, host.breakNowQuickActionEnabled else { return }
        guard !host.upcomingLaybys.isEmpty else { return }
        if host.hosEnabled {
            host.hosSnapshot = await host.hosClock.snapshot()
        }
        let arcLength = host.simulationEngine.currentArcLengthMeters
        let speedMps = max(host.simulationEngine.currentSpeedKmh / 3.6, 1.0)
        let input = host.laybyPredictionInput(
            currentArcLengthMeters: arcLength,
            speedMps: speedMps
        )
        guard let advisory = await host.rankBreakNowLayby(
            currentArcLengthMeters: arcLength,
            speedMps: speedMps,
            predictionInput: input
        ) else { return }
        host.laybyAdvisory = advisory
        host.focusMapOnLayby(advisory)
        host.tripBriefShareText = TripBriefFormatter.plainText(from: host.tripBriefContext())
    }
}
