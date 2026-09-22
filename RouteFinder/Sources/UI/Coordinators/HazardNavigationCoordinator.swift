import Contracts
import DataLayer
import Foundation
import RouteController

/// Mutable hazard navigation state owned by ``RouteViewModel``.
@MainActor
public final class HazardNavigationState {
    /// GeoJSON hazard overlay for the map.
    public var hazardOverlayJSON = HazardOverlayBuilder.emptyFeatureCollection
    /// Nearest proactive hazard announcement along the active route, if any.
    public var activeHazardAheadAnnouncement: HazardAheadAnnouncement?
    /// Nearest roadworks site ahead on the active route, if any.
    public var activeRoadworksAhead: RoadworkSite?
    /// Crowd-sourced reports used for hazard promotion and trip brief.
    public var crowdReports: [CrowdReport] = []
}

/// Route and navigation context for hazard orchestration.
@MainActor
public struct HazardNavigationContext {
    /// Active route polyline coordinates.
    public var routeCoordinates: [Coordinate]
    /// Arc length along the route in meters.
    public var currentRouteArcLengthMeters: Double
    /// Whether a route is loaded.
    public var hasActiveRoute: Bool
    /// TomTom API key when configured.
    public var tomTomAPIKey: String
    /// Whether TomTom traffic sampling is available.
    public var hasTomTomAPIKey: Bool
    /// Resolved vehicle class for hazard thresholds.
    public var vehicleClass: VehicleProfileClass
    /// Display measurement system for hazard copy.
    public var displayMeasurementSystem: RegionalMeasurementSystem
    /// Whether spoken hazard alerts are enabled.
    public var hazardVoiceAlertsEnabled: Bool
    /// When set, legacy hazard TTS is skipped for this hazard id (fused ``RouteRiskAdvisory`` owns voice).
    public var fusedHazardVoiceId: String?

    /// Creates hazard navigation context.
    public init(
        routeCoordinates: [Coordinate],
        currentRouteArcLengthMeters: Double,
        hasActiveRoute: Bool,
        tomTomAPIKey: String,
        hasTomTomAPIKey: Bool,
        vehicleClass: VehicleProfileClass,
        displayMeasurementSystem: RegionalMeasurementSystem,
        hazardVoiceAlertsEnabled: Bool,
        fusedHazardVoiceId: String? = nil
    ) {
        self.routeCoordinates = routeCoordinates
        self.currentRouteArcLengthMeters = currentRouteArcLengthMeters
        self.hasActiveRoute = hasActiveRoute
        self.tomTomAPIKey = tomTomAPIKey
        self.hasTomTomAPIKey = hasTomTomAPIKey
        self.vehicleClass = vehicleClass
        self.displayMeasurementSystem = displayMeasurementSystem
        self.hazardVoiceAlertsEnabled = hazardVoiceAlertsEnabled
        self.fusedHazardVoiceId = fusedHazardVoiceId
    }
}

#if os(iOS)
/// Speaks hazard advisories when voice guidance is enabled.
@MainActor
public protocol HazardVoiceAnnouncing: AnyObject {
    func speakHazardAdvisory(_ prompt: String, hazardId: String)
}
#endif

/// Coordinates hazard overlays, TomTom sampling, roadworks, and crowd hydration.
@MainActor
public final class HazardNavigationCoordinator {
    private let roadworksRepository = RoadworksAlongRouteRepository()
    private let crowdEventIngest = LocalCrowdEventIngest()
    private var activeHazards: [HazardEvent] = []
    private var tomTomTrafficHazardHit: TomTomTrafficHazardHit?
    private var lastTomTomHazardSampleDate: Date?
    private var tomTomHazardSampleTask: Task<Void, Never>?
    private var upcomingRoadworks: [RoadworkSite] = []
    private var roadworksLoadTask: Task<Void, Never>?
    private var lastAnnouncedHazardId: String?

    #if os(iOS)
    private weak var voiceAnnouncer: HazardVoiceAnnouncing?
    #endif
    /// Called on the main actor after async hazard state mutations.
    public var onStateChanged: (@MainActor () -> Void)?

    /// Creates a hazard navigation coordinator.
    public init() {}

    #if os(iOS)
    /// Attaches the voice announcer for spoken hazard alerts.
    public func bindVoiceAnnouncer(_ announcer: HazardVoiceAnnouncing) {
        voiceAnnouncer = announcer
    }
    #endif

    /// Hydrates crowd reports from disk and rebuilds hazard overlays.
    public func hydrateCrowdReportsFromDisk(
        state: HazardNavigationState,
        hasActiveRoute: Bool,
        context: HazardNavigationContext?
    ) async {
        let stored = await crowdEventIngest.allReports()
        state.crowdReports = stored
        activeHazards = HazardAheadFormatter.promotedHazards(from: state.crowdReports)
        state.hazardOverlayJSON = HazardOverlayBuilder.geoJSON(from: activeHazards)
        if hasActiveRoute {
            refreshHazardAheadAnnouncement(state: state, context: context)
        }
    }

    /// Refreshes the nearest closure/traffic hazard ahead on the active route.
    public func refreshHazardAheadAnnouncement(
        state: HazardNavigationState,
        context: HazardNavigationContext?
    ) {
        guard let context else {
            state.activeHazardAheadAnnouncement = nil
            return
        }
        guard context.routeCoordinates.count >= 2 else {
            state.activeHazardAheadAnnouncement = nil
            return
        }
        state.activeHazardAheadAnnouncement = HazardAheadFormatter.nearestAhead(
            hazards: activeHazards,
            crowdReports: state.crowdReports,
            route: context.routeCoordinates,
            currentArcLengthMeters: context.currentRouteArcLengthMeters,
            tomTomHits: tomTomTrafficHazardHit.map { [$0] } ?? []
        )
        #if os(iOS)
        processHazardVoiceAlertIfNeeded(state: state, context: context)
        #endif
    }

    /// Polls TomTom flow ahead of the vehicle when keyed, throttled, and within budget.
    public func sampleTomTomHazardAheadIfNeeded(
        state: HazardNavigationState,
        context: HazardNavigationContext
    ) {
        guard context.hasTomTomAPIKey, context.hasActiveRoute else { return }
        guard LiveTrafficHazardSampler.shouldPoll(lastSampleDate: lastTomTomHazardSampleDate) else { return }
        guard context.routeCoordinates.count >= 2 else { return }

        let arcLength = context.currentRouteArcLengthMeters
        let apiKey = context.tomTomAPIKey
        let vehicleClass = context.vehicleClass
        let measurementSystem = context.displayMeasurementSystem

        tomTomHazardSampleTask?.cancel()
        tomTomHazardSampleTask = Task { @MainActor in
            guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .tomTomFlow) else {
                return
            }
            do {
                let client = try TomTomTrafficFlowClient(apiKey: apiKey)
                let hit = await LiveTrafficHazardSampler.sampleAhead(
                    route: context.routeCoordinates,
                    currentArcLengthMeters: arcLength,
                    trafficClient: client,
                    vehicleClass: vehicleClass,
                    measurementSystem: measurementSystem
                )
                guard !Task.isCancelled else { return }
                lastTomTomHazardSampleDate = Date()
                tomTomTrafficHazardHit = hit
                refreshHazardAheadAnnouncement(state: state, context: context)
                onStateChanged?()
            } catch {
                guard !Task.isCancelled else { return }
                lastTomTomHazardSampleDate = Date()
                onStateChanged?()
            }
        }
    }

    /// Searches OSM roadworks / construction nodes within the route corridor.
    public func loadRoadworksAlongRoute(
        state: HazardNavigationState,
        coordinates: [Coordinate],
        currentArcLengthMeters: Double
    ) {
        roadworksLoadTask?.cancel()
        upcomingRoadworks = []
        state.activeRoadworksAhead = nil
        roadworksLoadTask = Task { @MainActor in
            guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .overpass) else { return }
            do {
                let sites = try await roadworksRepository.queryAlongRoute(
                    route: coordinates,
                    aheadMeters: 32_000,
                    fromArcLengthMeters: currentArcLengthMeters,
                    corridorHalfWidthMeters: 400
                )
                guard !Task.isCancelled else { return }
                upcomingRoadworks = sites
                refreshActiveRoadworksAhead(state: state, currentArcLengthMeters: currentArcLengthMeters)
                onStateChanged?()
            } catch {
                guard !Task.isCancelled else { return }
                upcomingRoadworks = []
                state.activeRoadworksAhead = nil
                onStateChanged?()
            }
        }
    }

    /// Updates the nearest roadworks site ahead from the cached corridor query.
    public func refreshActiveRoadworksAhead(
        state: HazardNavigationState,
        currentArcLengthMeters: Double
    ) {
        state.activeRoadworksAhead = RoadworksAheadFormatter.nearestAhead(
            sites: upcomingRoadworks,
            currentArcLengthMeters: currentArcLengthMeters
        )
    }

    /// Appends a hazard event and rebuilds the map overlay.
    public func appendHazardOverlay(
        _ hazard: HazardEvent,
        state: HazardNavigationState,
        context: HazardNavigationContext?
    ) {
        activeHazards.append(hazard)
        state.hazardOverlayJSON = HazardOverlayBuilder.geoJSON(from: activeHazards)
        refreshHazardAheadAnnouncement(state: state, context: context)
    }

    /// Records a crowd report and promotes confident hazards.
    @discardableResult
    public func recordCrowdReport(_ report: CrowdReport, state: HazardNavigationState) -> HazardEvent? {
        state.crowdReports.append(report)
        let inputs = CrowdConfidenceInputs(
            uniqueVehiclesNearby: 3,
            ageSeconds: 0,
            reporterReputation: 0.8,
            corroborationCount: 1
        )
        guard let hazard = CrowdEventBus.promoteIfConfident(
            report: report,
            inputs: inputs,
            severity: .moderate
        ) else {
            return nil
        }
        activeHazards.append(hazard)
        state.hazardOverlayJSON = HazardOverlayBuilder.geoJSON(from: activeHazards)
        return hazard
    }

    /// Persists a crowd report to disk ingest.
    public func persistCrowdReport(
        _ report: CrowdReport,
        scoreInputs: CrowdConfidenceInputs? = nil
    ) async {
        try? await crowdEventIngest.submit(report)
        let inputs = scoreInputs ?? CrowdConfidenceInputs(
            uniqueVehiclesNearby: 3,
            ageSeconds: 0,
            reporterReputation: 0.8,
            corroborationCount: 1
        )
        _ = await crowdEventIngest.score(reportId: report.id, inputs: inputs)
    }

    /// Clears hazard, TomTom, and roadworks state when the route is reset.
    public func resetRouteHazardState(state: HazardNavigationState) {
        state.activeHazardAheadAnnouncement = nil
        state.activeRoadworksAhead = nil
        upcomingRoadworks = []
        activeHazards = []
        lastAnnouncedHazardId = nil
        tomTomTrafficHazardHit = nil
        lastTomTomHazardSampleDate = nil
        tomTomHazardSampleTask?.cancel()
        tomTomHazardSampleTask = nil
        roadworksLoadTask?.cancel()
        state.hazardOverlayJSON = HazardOverlayBuilder.emptyFeatureCollection
    }

    #if os(iOS)
    private func processHazardVoiceAlertIfNeeded(
        state: HazardNavigationState,
        context: HazardNavigationContext
    ) {
        guard context.hazardVoiceAlertsEnabled,
              let announcement = state.activeHazardAheadAnnouncement else { return }
        // Unified predictive-risk fuse owns TTS when it already covers this hazard/traffic.
        if let fusedId = context.fusedHazardVoiceId,
           fusedId == announcement.id || fusedId.hasSuffix("-\(announcement.id)") {
            lastAnnouncedHazardId = announcement.id
            return
        }
        let threshold = NavigationWorkspaceSettings.loadHazardAlertDistanceMeters()
        guard HazardAheadFormatter.shouldAnnounce(
            announcement: announcement,
            lastAnnouncedHazardId: lastAnnouncedHazardId,
            alertDistanceMeters: threshold
        ) else { return }
        voiceAnnouncer?.speakHazardAdvisory(
            HazardAheadFormatter.spokenPrompt(for: announcement),
            hazardId: announcement.id
        )
        lastAnnouncedHazardId = announcement.id
    }
    #endif
}

#if os(iOS)
extension VoiceGuidanceCoordinator: HazardVoiceAnnouncing {}
#endif
