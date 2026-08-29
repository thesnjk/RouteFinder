import Contracts
import CoreLocation
import CostModel
import DataLayer
import MapLibreUI
import NavigationCore
import RouteController
import SharedCore
import SwiftUI

/// Pending geocode disambiguation request.
public struct GeocodeDisambiguationRequest: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let query: String
    public let waypointID: UUID
    public let candidates: [GeocodeSuggestion]

    public init(query: String, waypointID: UUID, candidates: [GeocodeSuggestion]) {
        self.id = UUID()
        self.query = query
        self.waypointID = waypointID
        self.candidates = candidates
    }
}

/// Editable physics sidebar field identifiers.
public enum VehiclePhysicsField: String, Sendable, Hashable, CaseIterable {
    case axleWeight
    case turningRadius
    case groundClearance
}

/// Parses optional numeric vehicle dimension strings from the UI.
public enum VehicleDimensionParser {
    /// Parses an optional positive double from user text input.
    public static func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}

/// Default map viewport for cloud-only routing (UK centroid).
public enum MapDefaults {
    /// Approximate geographic centre of Great Britain.
    public static let ukCenter = Coordinate(latitude: 54.0, longitude: -2.5)
}

/// View model connecting UI state to the routing engine.
@MainActor
@Observable
public final class RouteViewModel {
    public var routeWaypoints: [RouteWaypoint] = [
        RouteWaypoint(role: .origin),
        RouteWaypoint(role: .destination),
    ]
    public var searchSuggestions: [UUID: [GeocodeSuggestion]] = [:]
    public var searchFeedback: [UUID: String] = [:]

    public var optimizationMode: OptimizationMode = .fastest
    public var avoidTolls = false
    public var avoidFerries = false
    public var avoidTunnels = false
    /// When on, ORS avoids UK LEZ/CAZ zones the vehicle emission class does not meet (default on).
    public var avoidNonCompliantLEZ = true
    public var hurryMode = false
    public var isHGVMode = false
    public var avoidResidential = true
    public var avoidCameras = false
    public var avoidHazmatRestricted = false
    public var enforceTurnRadius = false
    public var enforceCurveSpeed = false
    public var useAppleSearchFallback = false
    public var useAStar = true
    public var routingEngine: RoutingEngine = .defaultEngine
    public var orsAPIKey: String = ""
    /// Draft text for Settings SecureField (never pre-filled from the vault).
    public var orsAPIKeyDraft: String = ""
    public var hasORSAPIKey = false
    public var vehicleHeight: String = ""
    public var vehicleWeight: String = ""
    public var vehicleWidth: String = ""
    public var vehicleLength: String = ""
    public var vehicleAxleWeight: String = ""
    public var vehicleGroundClearance: String = ""
    public var vehicleTurningRadius: String = ""
    /// Physics fields explicitly edited by the user (non-placeholder).
    public var userOverriddenPhysicsFields: Set<VehiclePhysicsField> = []
    public var hazmatClass: HazmatClass?
    public var tunnelRestrictionCode: TunnelRestrictionCode?
    public var emissionClass: EmissionClass?
    public var activeProfileName: String?
    public var vehicleRegistration: String = ""
    /// Dial / turn-list display units from registration origin (UK/US → mph, EU → km/h).
    public var displayMeasurementSystem: RegionalMeasurementSystem {
        TelemetryUnitConverter.displayMeasurementSystem(
            forRegistration: vehicleRegistration,
            fallbackCoordinate: routeCoordinates.first
                ?? simulationEngine.currentCoordinate
                ?? CLLocationCoordinate2D(
                    latitude: mapViewportCenter.latitude,
                    longitude: mapViewportCenter.longitude
                )
        )
    }
    public var vehicleTypeLabel: String = ""
    public var vehicleAxleCount: String = ""
    public var vehicleEnginePowerHP: String = ""
    public var registrationLookupError: String?
    public var registrationLookupInProgress = false
    /// Cached registration plates from prior successful lookups.
    public var plateLibraryEntries: [VehiclePlateLibraryEntry] = []
    public var registrationSource: RegistrySource?
    public var resolvedSpecificationProfile: VehicleSpecificationProfile?
    public var dvlaAPIKey: String = ""
    public var dvlaAPIKeyDraft: String = ""
    public var hasDVLAAPIKey = false
    public var regCheckUsername: String = ""
    public var regCheckUsernameDraft: String = ""
    public var hasRegCheckUsername = false
    public var vehicleClassOverride: VehicleProfileClass?
    public var tomTomAPIKey: String = ""
    public var tomTomAPIKeyDraft: String = ""
    public var hasTomTomAPIKey = false
    public var openWeatherAPIKey: String = ""
    public var openWeatherAPIKeyDraft: String = ""
    public var hasOpenWeatherAPIKey = false
    public var environmentalContext: EnvironmentalContext = .dry
    public var isOptimizing = false
    public var optimizationError: String?
    public var autoOptimizeOnRouteFind = NavigationWorkspaceSettings.loadAutoOptimizeOnRouteFind()
    public var preferredTelemetryMode = NavigationWorkspaceSettings.loadTelemetrySourceMode()
    #if os(iOS)
    public var voiceGuidanceEnabled = NavigationWorkspaceSettings.loadVoiceGuidanceEnabled()
    #endif

    /// Whether the advisory EU hours-of-service clock is enabled.
    public var hosEnabled = NavigationWorkspaceSettings.loadHosAdvisoryClockEnabled()
    /// When true, TomTom congestion caps simulation cruise speed (default off).
    public var applyTrafficToSimulation = NavigationWorkspaceSettings.loadApplyTrafficToSimulation()
    /// When true, live traffic jams can trigger avoid-polygon reroute evaluation.
    public var avoidTrafficDelaysWhenRouting = NavigationWorkspaceSettings.loadAvoidTrafficDelaysWhenRouting()
    /// When true, show Break Now layby quick action on the map HUD (default on).
    public var breakNowQuickActionEnabled = NavigationWorkspaceSettings.loadBreakNowQuickActionEnabled()
    /// Whether spoken layby-ahead alerts are enabled.
    public var laybyVoiceAlertsEnabled = NavigationWorkspaceSettings.loadLaybyVoiceAlertsEnabled()
    /// Selected fleet fuel card provider for ahead-of-route POI matching.
    public var fuelCardProvider = NavigationWorkspaceSettings.loadFuelCardProvider()
    /// Whether spoken closure/traffic hazard-ahead alerts are enabled.
    public var hazardVoiceAlertsEnabled = NavigationWorkspaceSettings.loadHazardVoiceAlertsEnabled()
    /// Nearest proactive hazard announcement along the active route, if any.
    public var activeHazardAheadAnnouncement: HazardAheadAnnouncement? {
        get { hazardState.activeHazardAheadAnnouncement }
        set { hazardState.activeHazardAheadAnnouncement = newValue }
    }
    /// Nearest roadworks site ahead on the active route, if any.
    public var activeRoadworksAhead: RoadworkSite? {
        get { hazardState.activeRoadworksAhead }
        set { hazardState.activeRoadworksAhead = newValue }
    }
    /// Rolled-up external API usage for Settings.
    public var apiUsageSummary: APIUsageDaySummary?
    /// Banner when non-critical API polls are paused for budget protection.
    public var apiUsageBudgetBanner: String?
    /// Bumped when hazard coordinator mutates shared hazard state asynchronously.
    public private(set) var hazardStateVersion = 0
    /// Preferred Pelias search language code (BCP-47).
    public var preferredSearchLanguage = LanguageWorkspaceSettings.loadPreferredSearchLanguage()
    /// When true, run a secondary English Pelias pass when localized results are sparse.
    public var searchEnglishFallback = LanguageWorkspaceSettings.loadSearchEnglishFallback()
    /// Preferred OpenFreeMap basemap label language code (BCP-47).
    public var preferredMapLabelLanguage = LanguageWorkspaceSettings.loadPreferredMapLabelLanguage()
    /// When true, tiled offline routing may be used (fallback or primary).
    public var offlineRoutingEnabled = VehicleProfileStore.loadOfflineRoutingEnabled()
    /// When true, prefer offline tiles over ORS even when online and keyed.
    public var preferOfflineRouting = VehicleProfileStore.loadPreferOfflineRouting()
    /// Configurable HTTPS base for `*.graphjson` tile downloads.
    public var tileServerURL: String = VehicleProfileStore.loadTileServerURL() ?? ""
    /// Status string for UK / demo corridor tile downloads.
    public var offlineTileStatus: String?
    /// Whether a corridor download is in progress.
    public var isDownloadingOfflineTiles = false
    /// Whether MapLibre should use a local map pack when present.
    public var useLocalMapStyleWhenPackPresent = VehicleProfileStore.loadUseLocalMapStyleWhenPackPresent()
    /// Human-readable offline map pack status for Settings.
    public var offlineMapPackStatus: String = "Checking map pack…"
    /// Active MapLibre style URL (CDN or localhost pack).
    public var mapStyleURL: String = MapLibreConfiguration.openFreeMapStyleURL
    /// Whether the initial offline-map-pack style resolution pass has completed.
    public var mapStyleResolved = false
    /// Latest HOS snapshot for HUD.
    public var hosSnapshot: HosClockSnapshot?
    /// Latest HOS rest forecast for the active route / trip brief.
    public var hosForecast: HosRestInsertionResult?
    /// Latest imported driver-card remaining-time summary (advisory).
    public var tachoSummary: TachoCardSummary?
    /// Latest “Can I drive now?” advisory status.
    public var canIDriveStatus: CanIDriveStatus?
    /// Error from the most recent tachograph file import, if any.
    public var tachoImportError: String?

    public var isCalculating = false
    public var result: SearchResult?
    public var errorMessage: String?
    public var routeFailure: RouteFailurePresentation?
    /// Incremented when a route failure should collapse the bottom sheet detail.
    public var routeDetailCollapseTick: Int = 0
    public var cloudRoutingBanner: String?
    public var routeCoordinates: [CLLocationCoordinate2D] = []
    public var routeCumulativeLengths: [Double] = []
    public var routeGeometry: RouteGeometry?
    public var routeEncodedPolyline: String?
    public var routeEncodedPolylinePrecision: Int = 6
    public var hazardOverlayJSON: String {
        get { hazardState.hazardOverlayJSON }
        set { hazardState.hazardOverlayJSON = newValue }
    }

    #if os(iOS)
    public var isFollowModeEnabled = false
    public var isNavigationActive = false
    #endif

    /// Active fleet trip id when the driver device is working a dispatch.
    public var activeDispatchTripId: UUID?
    /// Company break windows from the active dispatched trip.
    private var activeDispatchCompanyBreaks: [CompanyBreakAllocation] = []
    /// Shared fleet vehicle id for polling dispatched jobs (demo / MVP).
    public var fleetVehicleId: UUID?
    /// Text binding for Settings fleet vehicle UUID entry.
    public var fleetVehicleIdText: String = ""
    /// Text binding for Settings fleet server URL entry.
    public var fleetServerURLText: String = ""
    /// Text binding for Settings fleet server API key entry.
    public var fleetServerAPIKeyText: String = ""
    /// Whether Settings uses the remote fleet HTTP server.
    public var useRemoteFleetServer: Bool = false
    /// Last fleet server connection test result for Settings UI.
    public var fleetServerConnectionStatus: String?
    /// Fleet servers discovered via Bonjour on the local network.
    public var discoveredFleetServers: [DiscoveredFleetServer] = []
    /// Whether a Bonjour fleet discovery scan is in progress.
    public var isDiscoveringFleetServers = false
    /// Status text for Bonjour fleet discovery in Settings.
    public var fleetDiscoveryStatus: String?
    /// Driver banner when a remote dispatch arrives via SSE.
    public var fleetDispatchToast: String?
    /// Last published fleet snapshot for dispatch console visibility.
    public var lastPublishedFleetSnapshot: FleetTripSnapshot?

    public var interactionMode: MapInteractionMode = .navigate
    public var activePinTarget: MapPinTarget = .none
    public var pendingDisambiguation: GeocodeDisambiguationRequest?

    /// Upcoming layby advisory for the active route, when within alert range.
    public var laybyAdvisory: LaybyAdvisory?
    /// All layby candidates discovered along the current route.
    public var upcomingLaybys: [LaybyStop] = []
    /// Whether layby POIs are being fetched for the current route.
    public var isLoadingLaybys = false
    /// Truck fuel / parking / weigh POIs ahead along the route.
    public var upcomingTruckPois: [TruckPoi] = []
    /// Whether truck POI search is in progress.
    public var isLoadingTruckPois = false
    /// LEZ / restriction announcements for the active route.
    public var restrictionAnnouncements: [RestrictionZoneAnnouncement] = []
    /// Nearest upcoming restriction for HUD.
    public var activeRestrictionAnnouncement: RestrictionZoneAnnouncement?
    /// `true` when TomTom detected delay and an avoid-polygon alternate is ready to apply.
    public var trafficRerouteAvailable = false
    /// Whether a background traffic re-route evaluation is running.
    public var isEvaluatingTrafficReroute = false

    /// Physics-predicted route duration from headless simulation, when available.
    public var physicsPredictedDurationSeconds: TimeInterval?
    /// Planned journey duration from the physics estimator (frozen for the trip).
    public var journeyPhysicsETASeconds: TimeInterval?
    /// Wall-clock moment when the physics journey ETA was committed.
    public var journeyETAAnchorDate: Date?
    /// Whether a headless physics duration estimate is running.
    public var isEstimatingPhysicsDuration = false
    /// True while a pre-trip route rehearsal is running.
    public var isRehearsingRoute = false
    /// Latest live kinetic advisory for HUD (fade, grade, slip).
    public var latestKineticAdvisory: KineticAdvisory?
    /// Shareable plain-text trip brief from the latest predictive report.
    public var tripBriefShareText: String?
    /// Latest saved walkaround summary for trip brief and fleet handoff.
    public var latestInspectionSummary: TripBriefInspectionSummary?
    /// Map camera zoom while simulating (user-adjustable).
    public var simulationCameraZoom: Double = 15.0
    /// When true, auto camera tracking will not override the sim zoom slider.
    public var simulationZoomLockedByUser = false
    /// Active structured lane guidance near the upcoming maneuver.
    public var activeLaneGuidance: LaneGuidance?
    /// Maneuver associated with ``activeLaneGuidance``.
    public var activeLaneManeuver: TurnManeuver?
    /// Distance to the maneuver for ``activeLaneGuidance``.
    public var activeLaneDistanceMeters: Double?
    /// Presents the Waze-style hazard report sheet.
    public var presentHazardReportSheet = false
    /// Pending “still there?” prompt for a recent crowd report.
    public var pendingStillTherePrompt: CrowdReportStillTherePrompt?

    public var mapViewportCenter = MapDefaults.ukCenter

    public var mapRegion = MapRegion(
        center: CLLocationCoordinate2D(
            latitude: MapDefaults.ukCenter.latitude,
            longitude: MapDefaults.ukCenter.longitude
        ),
        latitudeDelta: 0.8,
        longitudeDelta: 0.8
    )

    /// Physics-based route simulation engine.
    public let simulationEngine: RouteSimulationEngine

    /// Navigation session coordinator for live progress and location ingestion.
    public let navigationCoordinator: NavigationCoordinator

    /// Live navigation metrics for the route summary card.
    public var navigationMetrics: NavigationMetricsViewModel {
        navigationCoordinator.metricsViewModel
    }

    /// Map camera tracking and LOD coordinator.
    public var mapBridge: MapViewControllerBridge?

    /// Current simulated vehicle coordinate for map binding.
    public var simulatedCoordinate: CLLocationCoordinate2D? {
        simulationEngine.currentCoordinate
    }

    /// Current simulated vehicle bearing in degrees.
    public var simulatedBearing: Double {
        simulationEngine.currentBearing
    }

    /// First stop (origin).
    public var originWaypoint: RouteWaypoint {
        routeWaypoints.first ?? RouteWaypoint(role: .origin)
    }

    /// Last stop (destination).
    public var destinationWaypoint: RouteWaypoint {
        routeWaypoints.last ?? RouteWaypoint(role: .destination)
    }

    /// Intermediate via stops between origin and destination.
    public var viaWaypoints: [RouteWaypoint] {
        guard routeWaypoints.count > 2 else { return [] }
        return Array(routeWaypoints.dropFirst().dropLast())
    }

    public var showsHGVRouteFailureBanner: Bool {
        guard let errorMessage else { return false }
        return errorMessage == ExternalRoutingError.hgvNoRouteMessage
    }

    public var isRouteDimensionBlocked: Bool {
        routeFailure?.kind == .routeBlocked
            || errorMessage == ExternalRoutingError.vehicleDimensionBlockedMessage
    }

    public var canFindRoute: Bool {
        let originText = originWaypoint.rawText.trimmingCharacters(in: .whitespaces)
        let destText = destinationWaypoint.rawText.trimmingCharacters(in: .whitespaces)
        return !originText.isEmpty && !destText.isEmpty
    }

    /// Pins to display on the map canvas.
    public var mapPins: [RoutePin] {
        routeWaypoints.compactMap { waypoint in
            guard let resolved = waypoint.resolved else { return nil }
            let kind: RoutePin.PinKind = switch waypoint.role {
            case .origin: .start
            case .destination: .end
            case .via: .waypoint
            }
            return RoutePin(
                id: waypoint.id.uuidString,
                coordinate: CLLocationCoordinate2D(
                    latitude: resolved.snappedCoordinate.latitude,
                    longitude: resolved.snappedCoordinate.longitude
                ),
                kind: kind,
                title: resolved.displayLabel
            )
        }
    }

    /// Map pins with the start marker hidden during live simulation so the vehicle footprint is visible.
    public var displayMapPins: [RoutePin] {
        if simulationEngine.isRunning {
            return mapPins.filter { $0.kind != .start }
        }
        return mapPins
    }

    func resolutionStatus(for waypointID: UUID) -> EndpointResolutionStatus {
        guard let waypoint = routeWaypoints.first(where: { $0.id == waypointID }) else {
            return .empty
        }
        return status(for: waypoint.resolved, text: waypoint.rawText)
    }

    func snapHint(for waypointID: UUID) -> String? {
        nil
    }

    private let planner = RoutePlanner()
    private let geocoder = OpenRouteServiceGeocoder()
    private let offlineGraphStore: DiskOfflineGraphStore
    private let mapPackStore = OfflineMapPackStore()
    private let appleGeocodeSearch = AppleGeocodeSearch()
    private let locationResolver = LocationResolver()
    private var vehicleRegistryClient = VehicleRegistryClient()
    private let plateLibraryStore = VehiclePlateLibraryStore()
    private var searchTasks: [UUID: Task<Void, Never>] = [:]
    private var hasCompletedCloudRoute = false
    private let laybyCatalogService = LaybyCatalogService()
    private let truckPoiRepository = OverpassTruckPoiRepository()
    private let hazardState = HazardNavigationState()
    @ObservationIgnored private var fleetDispatchCoordinator: FleetDispatchCoordinator!
    @ObservationIgnored private var routePlanningCoordinator: RoutePlanningCoordinator!
    @ObservationIgnored private var routeSimulationCoordinator: RouteSimulationCoordinator!
    @ObservationIgnored private var hosAdvisoryCoordinator: HosAdvisoryCoordinator!
    @ObservationIgnored private let hazardNavigationCoordinator = HazardNavigationCoordinator()
    @ObservationIgnored private let fleetStoreConfigurationObserver = FleetStoreConfigurationObserver()
    /// In-memory driver alert bus (HOS and related).
    public let hosAlertBus: InMemoryDriverAlertBus
    /// Advisory EU 561 hours-of-service clock.
    public let hosClock: EU561HosClock
    /// Best-effort DDD / JSON driver-card importer.
    public let tachoImporter = DDDImporter()
    /// Local DVSA walkaround inspection store.
    public let inspectionStore = DiskInspectionStore()
    /// Active walkaround checklist for the inspection sheet.
    public var activeInspection: InspectionRecord?
    private var crowdReports: [CrowdReport] {
        get { hazardState.crowdReports }
        set { hazardState.crowdReports = newValue }
    }
    private let laybyAdvisor = LaybyAdvisor()
    private var laybyLoadTask: Task<Void, Never>?
    private var truckPoiLoadTask: Task<Void, Never>?
    /// Pending traffic-aware alternate response when `trafficRerouteAvailable` is true.
    public var pendingTrafficAlternate: ExternalRouteResponse?
    private var lastExternalRouteRequest: ExternalRouteRequest?

    #if os(iOS)
    private let voiceGuidanceCoordinator = VoiceGuidanceCoordinator()
    #endif
    private var vehicleWorkspacePersistTask: Task<Void, Never>?
    private let laneGuidanceNavigationAdapter = LaneGuidanceNavigationAdapter()
    private let navigationProgressRefreshAdapter = NavigationProgressRefreshAdapter()


    private var apiKeyVault: APIKeyVault?

    public convenience init() {
        self.init(vault: nil)
    }

    public init(vault: APIKeyVault?) {
        apiKeyVault = vault
        let alertBus = InMemoryDriverAlertBus()
        hosAlertBus = alertBus
        hosClock = EU561HosClock(alertBus: alertBus)
        let tileURLString = VehicleProfileStore.loadTileServerURL()
        let tileBase = tileURLString.flatMap { URL(string: $0) }
        offlineGraphStore = DiskOfflineGraphStore(tileBaseURL: tileBase)
        let snapshot = Self.loadSecretsSnapshot(from: vault)
        let secrets = snapshot.secrets
        let savedTomTomKey = secrets[.tomTom] ?? VehicleProfileStore.loadTomTomAPIKey()
        let engine = RouteSimulationEngine(tomTomAPIKey: savedTomTomKey)
        simulationEngine = engine
        navigationCoordinator = NavigationCoordinator { [weak engine] in
            guard let engine else {
                return VehicleMapDimensions(lengthMeters: 12, widthMeters: 2.55)
            }
            return VehicleMapDimensions(
                lengthMeters: engine.vehicleLengthMeters,
                widthMeters: engine.vehicleWidthMeters
            )
        }
        applyLoadedSecrets(
            ors: secrets[.ors] ?? VehicleProfileStore.loadORSAPIKey(),
            dvla: secrets[.dvla] ?? VehicleProfileStore.loadDVLAAPIKey(),
            regCheck: secrets[.regCheckUsername] ?? VehicleProfileStore.loadRegCheckUsername(),
            tomTom: savedTomTomKey,
            openWeather: secrets[.openWeather] ?? VehicleProfileStore.loadOpenWeatherAPIKey()
        )
        if let vaultLoadError = snapshot.loadError {
            errorMessage = vaultLoadError
        }
        #if os(macOS)
        if orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            useAppleSearchFallback = true
        }
        #endif
        wireNavigationPipeline()
        fleetDispatchCoordinator = FleetDispatchCoordinator(host: self)
        routePlanningCoordinator = RoutePlanningCoordinator(host: self)
        routeSimulationCoordinator = RouteSimulationCoordinator(host: self)
        hosAdvisoryCoordinator = HosAdvisoryCoordinator(host: self)
        routeSimulationCoordinator.wireSimulationCallbacks()
        hazardNavigationCoordinator.onStateChanged = { [weak self] in
            self?.hazardStateVersion &+= 1
        }
        restoreVehicleWorkspace()
        #if os(iOS)
        if VehicleWorkspaceSettings.load() == nil {
            isHGVMode = true
            applyHGVPreset()
        }
        #endif
        updateCloudRoutingBanner()
        fleetDispatchCoordinator.restoreWorkspaceSettings()
        #if os(iOS)
        hazardNavigationCoordinator.bindVoiceAnnouncer(voiceGuidanceCoordinator)
        #endif
        fleetStoreConfigurationObserver.token = NotificationCenter.default.addObserver(
            forName: .fleetStoreConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadFleetStore()
                await self?.pollAndApplyFleetDispatch()
            }
        }
        Task { @MainActor [weak self] in
            await self?.hosAdvisoryCoordinator.bootstrapFromDisk()
            await self?.refreshOfflineMapPackStatus()
            try? await self?.offlineGraphStore.loadLocalTiles()
            await self?.hydrateCrowdReportsFromDisk()
            await self?.refreshAPIUsageSummary()
        }
    }

    /// Refreshes API usage summary and budget banner for Settings.
    public func refreshAPIUsageSummary() async {
        apiUsageSummary = await APIUsageLedger.shared.summary()
        apiUsageBudgetBanner = await APIUsageLedger.shared.budgetBannerMessage()
    }

    /// Attaches or refreshes the on-disk API vault after login without re-reading when unchanged.
    public func bindVault(_ vault: APIKeyVault?) {
        let previousUserID = apiKeyVault?.userID
        apiKeyVault = vault
        guard let vault else { return }
        // Skip duplicate vault reload when ContentView already initialized with this vault.
        if previousUserID == vault.userID,
           hasORSAPIKey || hasDVLAAPIKey || hasTomTomAPIKey || hasOpenWeatherAPIKey || hasRegCheckUsername {
            return
        }
        let snapshot = Self.loadSecretsSnapshot(from: vault)
        applyLoadedSecrets(
            ors: snapshot.secrets[.ors],
            dvla: snapshot.secrets[.dvla],
            regCheck: snapshot.secrets[.regCheckUsername],
            tomTom: snapshot.secrets[.tomTom],
            openWeather: snapshot.secrets[.openWeather]
        )
        if let vaultLoadError = snapshot.loadError {
            errorMessage = vaultLoadError
        }
        updateCloudRoutingBanner()
    }

    private static func loadSecretsSnapshot(
        from vault: APIKeyVault?
    ) -> (secrets: [APIKeyKind: String], loadError: String?) {
        guard let vault else { return ([:], nil) }
        do {
            return (try vault.loadAll(), nil)
        } catch let error as KeychainStore.Error {
            return ([:], error.localizedDescription)
        } catch {
            return ([:], error.localizedDescription)
        }
    }

    private func applyLoadedSecrets(
        ors: String?,
        dvla: String?,
        regCheck: String?,
        tomTom: String?,
        openWeather: String?
    ) {
        if let ors, !ors.isEmpty {
            orsAPIKey = ors
            hasORSAPIKey = true
        } else {
            hasORSAPIKey = false
        }
        orsAPIKeyDraft = ""
        if let dvla, !dvla.isEmpty {
            dvlaAPIKey = dvla
            hasDVLAAPIKey = true
            VehicleProfileStore.saveDVLAAPIKey(dvla)
        } else {
            hasDVLAAPIKey = false
        }
        dvlaAPIKeyDraft = ""
        if let regCheck, !regCheck.isEmpty {
            regCheckUsername = regCheck
            hasRegCheckUsername = true
            VehicleProfileStore.saveRegCheckUsername(regCheck)
        } else {
            hasRegCheckUsername = false
        }
        regCheckUsernameDraft = ""
        if let tomTom, !tomTom.isEmpty {
            tomTomAPIKey = tomTom
            hasTomTomAPIKey = true
        } else {
            hasTomTomAPIKey = false
        }
        tomTomAPIKeyDraft = ""
        if let openWeather, !openWeather.isEmpty {
            openWeatherAPIKey = openWeather
            hasOpenWeatherAPIKey = true
        } else {
            hasOpenWeatherAPIKey = false
        }
        openWeatherAPIKeyDraft = ""
    }

    private func loadSecret(_ kind: APIKeyKind) -> String? {
        guard let apiKeyVault else { return nil }
        return try? apiKeyVault.load(kind)
    }

    private func persistSecret(_ value: String, kind: APIKeyKind) {
        if let apiKeyVault {
            do {
                try apiKeyVault.save(value, for: kind)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        // Always mirror registry credentials for VehicleRegistryCoordinator.makeDefault().
        switch kind {
        case .ors: VehicleProfileStore.saveORSAPIKey(value)
        case .openWeather:
            VehicleProfileStore.saveOpenWeatherAPIKey(value)
            DefaultWeatherService.notifyConfigurationDidChange()
        case .dvla: VehicleProfileStore.saveDVLAAPIKey(value)
        case .tomTom: VehicleProfileStore.saveTomTomAPIKey(value)
        case .regCheckUsername: VehicleProfileStore.saveRegCheckUsername(value)
        }
    }

    private func wireNavigationPipeline() {
        laneGuidanceNavigationAdapter.onProgress = { [weak self] in
            self?.refreshActiveLaneGuidance()
        }
        navigationProgressRefreshAdapter.onThrottledProgress = { [weak self] in
            Task { @MainActor in
                await self?.refreshLaybyAdvisory()
                self?.refreshHazardAheadAnnouncement()
                self?.sampleTomTomHazardAheadIfNeeded()
                self?.refreshActiveRoadworksAhead()
            }
        }
        navigationCoordinator.session.addDelegate(laneGuidanceNavigationAdapter)
        navigationCoordinator.session.addDelegate(navigationProgressRefreshAdapter)
        NavigationSessionRegistry.shared = navigationCoordinator.session
        #if os(iOS)
        CarPlayServices.publish(session: navigationCoordinator.session)
        CarPlayServices.registerDelegate = { [weak self] delegate in
            self?.navigationCoordinator.session.addDelegate(delegate)
        }
        voiceGuidanceCoordinator.attach(to: navigationCoordinator.session)
        voiceGuidanceCoordinator.setEnabled(voiceGuidanceEnabled)
        navigationCoordinator.session.addDelegate(voiceGuidanceCoordinator)
        #endif
    }

    public func routingPreferences() -> RoutingPreferences {
        RoutingPreferences(
            optimizationMode: optimizationMode,
            avoidTolls: avoidTolls,
            avoidFerries: avoidFerries,
            avoidTunnels: avoidTunnels,
            hurryMode: hurryMode,
            isHGVMode: isHGVMode,
            avoidResidential: avoidResidential,
            avoidCameras: avoidCameras,
            avoidHazmatRestricted: avoidHazmatRestricted,
            enforceTurnRadius: enforceTurnRadius,
            enforceCurveSpeed: enforceCurveSpeed,
            vehicle: resolvedVehicleProfile(),
            algorithm: useAStar ? .aStar : .dijkstra,
            requestSegmentSpeedLimits: ORSAPIDefaults.supportsExtraInfo
        )
    }

    /// Builds a vehicle profile from current UI fields without physics defaults.
    public func currentVehicleProfile() -> VehicleProfile {
        VehicleProfile(
            height: VehicleDimensionParser.parseOptional(vehicleHeight),
            weight: VehicleDimensionParser.parseOptional(vehicleWeight),
            width: VehicleDimensionParser.parseOptional(vehicleWidth),
            length: VehicleDimensionParser.parseOptional(vehicleLength),
            axleWeight: VehicleDimensionParser.parseOptional(vehicleAxleWeight),
            groundClearance: VehicleDimensionParser.parseOptional(vehicleGroundClearance),
            turningRadius: VehicleDimensionParser.parseOptional(vehicleTurningRadius),
            hazmatClass: hazmatClass,
            tunnelRestrictionCode: tunnelRestrictionCode,
            emissionClass: emissionClass,
            savedProfileName: activeProfileName
        )
    }

    /// Vehicle class inferred from HGV mode and registry profile.
    public var resolvedVehicleClass: VehicleProfileClass {
        if let resolvedSpecificationProfile {
            return resolvedSpecificationProfile.vehicleClass
        }
        if let vehicleClassOverride {
            return vehicleClassOverride
        }
        return isHGVMode ? .heavyGoodsVehicle : .passengerCar
    }

    /// Resolved physics values using class defaults when UI fields are empty.
    public func resolvedVehiclePhysics() -> ResolvedVehiclePhysics {
        ResolvedVehiclePhysics.resolved(
            vehicleClass: resolvedVehicleClass,
            userOverrides: currentVehicleProfile(),
            specification: resolvedSpecificationProfile
        )
    }

    /// Builds a vehicle profile with class-specific physics defaults applied.
    public func resolvedVehicleProfile() -> VehicleProfile {
        let raw = currentVehicleProfile()
        let physics = resolvedVehiclePhysics()
        return VehicleProfile(
            height: raw.height,
            weight: raw.weight,
            width: raw.width,
            length: raw.length,
            axleWeight: physics.axleWeightTonnes,
            groundClearance: physics.groundClearanceMeters,
            turningRadius: physics.turningRadiusMeters,
            hazmatClass: raw.hazmatClass,
            tunnelRestrictionCode: raw.tunnelRestrictionCode,
            emissionClass: raw.emissionClass,
            savedProfileName: raw.savedProfileName
        )
    }

    /// Placeholder text for a physics field when the user has not entered a value.
    public func physicsPlaceholder(for field: VehiclePhysicsField) -> String {
        let physics = resolvedVehiclePhysics()
        switch field {
        case .axleWeight:
            return String(format: "%.2f", physics.axleWeightTonnes)
        case .turningRadius:
            return String(format: "%.1f", physics.turningRadiusMeters)
        case .groundClearance:
            return String(format: "%.2f", physics.groundClearanceMeters)
        }
    }

    /// Marks a physics field as user-edited when text changes away from empty.
    public func markPhysicsFieldEdited(_ field: VehiclePhysicsField, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            userOverriddenPhysicsFields.remove(field)
        } else {
            userOverriddenPhysicsFields.insert(field)
        }
    }

    /// Applies resolved physics defaults into sidebar fields after plate lookup / profile apply.
    public func applyPhysicsDefaultPlaceholdersIfNeeded() {
        let physics = resolvedVehiclePhysics()
        if !userOverriddenPhysicsFields.contains(.axleWeight) {
            vehicleAxleWeight = String(format: "%.2f", physics.axleWeightTonnes)
        }
        if !userOverriddenPhysicsFields.contains(.turningRadius) {
            vehicleTurningRadius = String(format: "%.1f", physics.turningRadiusMeters)
        }
        if !userOverriddenPhysicsFields.contains(.groundClearance) {
            vehicleGroundClearance = String(format: "%.2f", physics.groundClearanceMeters)
        }
    }

    /// Applies a vehicle profile to editable UI fields.
    public func applyProfile(_ profile: VehicleProfile) {
        vehicleHeight = profile.height.map { String($0) } ?? ""
        vehicleWeight = profile.weight.map { String($0) } ?? ""
        vehicleWidth = profile.width.map { String($0) } ?? ""
        vehicleLength = profile.length.map { String($0) } ?? ""
        vehicleAxleWeight = profile.axleWeight.map { String($0) } ?? ""
        vehicleGroundClearance = profile.groundClearance.map { String($0) } ?? ""
        vehicleTurningRadius = profile.turningRadius.map { String($0) } ?? ""
        hazmatClass = profile.hazmatClass
        tunnelRestrictionCode = profile.tunnelRestrictionCode
        emissionClass = profile.emissionClass
        activeProfileName = profile.savedProfileName
        refreshMapVehicleFootprint()
        scheduleVehicleWorkspacePersist()
        Task { await recalculateIfReady() }
    }

    /// Looks up a registration plate and applies the resolved vehicle profile.
    public func applyRegistrationLookup() async {
        registrationLookupError = nil
        registrationLookupInProgress = true
        defer { registrationLookupInProgress = false }

        let sanitized = RegistrationNormalizer.normalize(vehicleRegistration)
        guard !sanitized.isEmpty else {
            registrationLookupError = VehicleRegistryError.emptyRegistration.localizedDescription
            return
        }

        if let cached = await plateLibraryStore.entry(forRegistration: sanitized) {
            await applyResolvedSpecification(
                cached.specification,
                displayRegistration: cached.displayRegistration
            )
            await refreshPlateLibrary()
            return
        }

        guard hasRegCheckUsername else {
            registrationLookupError = VehicleRegistryError.notConfigured.localizedDescription
            return
        }

        do {
            let spec = try await vehicleRegistryClient.lookupSpecification(
                registration: sanitized,
                manualClassOverride: vehicleClassOverride
            )
            guard spec.source == .verifiedAPI else {
                registrationLookupError = "RegCheck lookup did not return verified vehicle data."
                return
            }
            let entry = VehiclePlateLibraryEntry(
                specification: spec,
                displayRegistration: RegistrationNormalizer.formatForDisplay(sanitized)
            )
            try await plateLibraryStore.upsert(entry)
            await applyResolvedSpecification(spec, displayRegistration: entry.displayRegistration)
            await refreshPlateLibrary()
        } catch {
            registrationLookupError = error.localizedDescription
            navigationCoordinator.reportInvalidVehicleProfile(error.localizedDescription)
            vehicleTypeLabel = ""
            registrationSource = nil
            resolvedSpecificationProfile = nil
            syncMapBridgeSpecificationProfile()
        }
    }

    /// Reloads the on-disk plate library for the vehicle profile UI.
    public func refreshPlateLibrary() async {
        plateLibraryEntries = await plateLibraryStore.allEntries()
    }

    /// Applies a cached plate library entry.
    public func applyPlateLibraryEntry(_ entry: VehiclePlateLibraryEntry) async {
        registrationLookupError = nil
        vehicleRegistration = entry.displayRegistration
        await applyResolvedSpecification(entry.specification, displayRegistration: entry.displayRegistration)
    }

    /// Renames a cached plate library entry.
    public func renamePlateLibraryEntry(registration: String, customName: String?) async {
        try? await plateLibraryStore.rename(registration: registration, customName: customName)
        await refreshPlateLibrary()
    }

    /// Deletes a cached plate library entry.
    public func deletePlateLibraryEntry(registration: String) async {
        try? await plateLibraryStore.delete(registration: registration)
        await refreshPlateLibrary()
    }

    private func applyResolvedSpecification(
        _ spec: VehicleSpecificationProfile,
        displayRegistration: String
    ) async {
        resolvedSpecificationProfile = spec
        syncMapBridgeSpecificationProfile()
        let profile = spec.toRegistryProfile()
        applyRegistryProfile(profile)
        vehicleRegistration = displayRegistration
        scheduleVehicleWorkspacePersist()
        validateRegistryStateAfterLookup(spec)

        if vehicleClassOverride != nil {
            simulationEngine.refreshLiveFootprint(
                lengthMeters: profile.lengthM,
                widthMeters: profile.widthM
            )
        }
        await simulationEngine.configureVehicleSpecification(
            spec,
            vehicle: resolvedVehicleProfile(),
            minimumTurnRadiusMeters: resolvedVehiclePhysics().turningRadiusMeters
        )
    }

    private func syncMapBridgeSpecificationProfile() {
        mapBridge?.activeSpecificationProfile = resolvedSpecificationProfile
    }

    private func applyRegistryProfile(_ profile: VehicleRegistryProfile) {
        vehicleHeight = String(profile.heightM)
        vehicleWidth = String(profile.widthM)
        vehicleLength = String(profile.lengthM)
        vehicleWeight = String(profile.weightTonnes)
        vehicleAxleCount = String(profile.axleCount)
        vehicleEnginePowerHP = String(format: "%.0f", profile.enginePowerHP)
        vehicleTypeLabel = profile.displayName
        registrationSource = profile.registrySource
        isHGVMode = profile.isHGVMode
        if profile.isHGVMode {
            avoidResidential = true
        }
        if let emissionClass = profile.emissionClass {
            self.emissionClass = emissionClass
        }
        activeProfileName = profile.displayName

        applyPhysicsDefaultPlaceholdersIfNeeded()
        refreshMapVehicleFootprint()
        Task { await recalculateIfReady() }
    }

    private func validateRegistryStateAfterLookup(_ spec: VehicleSpecificationProfile) {
        switch spec.vehicleClass {
        case .passengerCar:
            isHGVMode = false
        case .heavyGoodsVehicle:
            isHGVMode = true
        case .lightCommercialVehicle:
            break
        }
        applyPhysicsDefaultPlaceholdersIfNeeded()
    }

    /// Sets simulation playback speed from the segmented control.
    public func setSimulationSpeed(_ multiplier: SpeedMultiplier) {
        routeSimulationCoordinator.setSimulationSpeed(multiplier)
    }

    /// Updates map vehicle dimensions after profile changes.
    public func refreshMapVehicleFootprint() {
        let length = VehicleDimensionParser.parseOptional(vehicleLength) ?? vehicleLengthMetersFromProfile()
        let width = VehicleDimensionParser.parseOptional(vehicleWidth) ?? vehicleWidthMetersFromProfile()
        syncMapBridgeSpecificationProfile()
        simulationEngine.refreshLiveFootprint(lengthMeters: length, widthMeters: width)
    }

    private func vehicleLengthMetersFromProfile() -> Double {
        resolvedSpecificationProfile?.lengthMeters ?? 12.0
    }

    private func vehicleWidthMetersFromProfile() -> Double {
        resolvedSpecificationProfile?.widthMeters ?? 2.55
    }

    /// Persists the DVLA Vehicle Enquiry Service API key (optional; prefer when available).
    public func persistDVLAAPIKey() {
        let value = dvlaAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        dvlaAPIKey = value
        hasDVLAAPIKey = true
        dvlaAPIKeyDraft = ""
        persistSecret(value, kind: .dvla)
        vehicleRegistryClient = vehicleRegistryClient.rebuildProviders()
    }

    /// Persists the RegCheck account username to the on-disk vault.
    public func persistRegCheckUsername() {
        let value = regCheckUsernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        regCheckUsername = value
        hasRegCheckUsername = true
        regCheckUsernameDraft = ""
        persistSecret(value, kind: .regCheckUsername)
        vehicleRegistryClient = vehicleRegistryClient.rebuildProviders()
    }

    /// Persists the TomTom Traffic Flow API key to the on-disk vault.
    public func persistTomTomAPIKey() {
        let value = tomTomAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        tomTomAPIKey = value
        hasTomTomAPIKey = true
        tomTomAPIKeyDraft = ""
        persistSecret(value, kind: .tomTom)
    }

    /// Persists the OpenWeather API key to the on-disk vault.
    public func persistOpenWeatherAPIKey() {
        let value = openWeatherAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        openWeatherAPIKey = value
        hasOpenWeatherAPIKey = true
        openWeatherAPIKeyDraft = ""
        persistSecret(value, kind: .openWeather)
    }

    /// Re-applies the active environmental context to the running simulation.
    public func refreshSimulationEnvironment() {
        routeSimulationCoordinator.refreshSimulationEnvironment()
    }

    public var canOptimizeSequence: Bool {
        viaWaypoints.count >= 1
            && originWaypoint.resolved != nil
            && destinationWaypoint.resolved != nil
            && viaWaypoints.allSatisfy { $0.resolved != nil }
    }

    /// Persists auto-optimize preference.
    public func persistAutoOptimizeOnRouteFind() {
        NavigationWorkspaceSettings.saveAutoOptimizeOnRouteFind(autoOptimizeOnRouteFind)
    }

    /// Persists preferred telemetry source mode and updates the active registry when navigating.
    public func persistTelemetrySourceMode() {
        NavigationWorkspaceSettings.saveTelemetrySourceMode(preferredTelemetryMode)
        Task {
            #if os(iOS)
            let shouldSwitch = isNavigationActive || simulationEngine.isRunning
            #else
            let shouldSwitch = simulationEngine.isRunning
            #endif
            if shouldSwitch {
                try? await navigationCoordinator.telemetryRegistry.switchMode(to: preferredTelemetryMode)
            }
        }
    }

    #if os(iOS)
    /// Persists voice guidance preference.
    public func persistVoiceGuidanceEnabled() {
        NavigationWorkspaceSettings.saveVoiceGuidanceEnabled(voiceGuidanceEnabled)
        voiceGuidanceCoordinator.setEnabled(voiceGuidanceEnabled)
    }
    #endif

    /// Persists advisory HOS clock preference and refreshes HUD state.
    public func persistHosEnabled() {
        NavigationWorkspaceSettings.saveHosAdvisoryClockEnabled(hosEnabled)
        if hosEnabled {
            Task { await refreshHosSnapshot() }
        } else {
            hosSnapshot = nil
            hosForecast = nil
        }
    }

    /// Persists whether live traffic caps simulation cruise speed.
    public func persistApplyTrafficToSimulation() {
        NavigationWorkspaceSettings.saveApplyTrafficToSimulation(applyTrafficToSimulation)
        simulationEngine.updateApplyTrafficToSimulation(applyTrafficToSimulation)
    }

    /// Persists whether traffic reroute evaluation runs after route find.
    public func persistAvoidTrafficDelaysWhenRouting() {
        NavigationWorkspaceSettings.saveAvoidTrafficDelaysWhenRouting(avoidTrafficDelaysWhenRouting)
    }

    /// Persists Break Now quick action preference.
    public func persistBreakNowQuickActionEnabled() {
        NavigationWorkspaceSettings.saveBreakNowQuickActionEnabled(breakNowQuickActionEnabled)
    }

    /// Persists layby voice alert preference.
    public func persistLaybyVoiceAlertsEnabled() {
        NavigationWorkspaceSettings.saveLaybyVoiceAlertsEnabled(laybyVoiceAlertsEnabled)
    }

    /// Persists fleet fuel card provider preference.
    public func persistFuelCardProvider() {
        NavigationWorkspaceSettings.saveFuelCardProvider(fuelCardProvider)
    }

    /// Persists hazard voice alert preference.
    public func persistHazardVoiceAlertsEnabled() {
        NavigationWorkspaceSettings.saveHazardVoiceAlertsEnabled(hazardVoiceAlertsEnabled)
    }

    /// Persists preferred search language and English fallback settings.
    public func persistLanguageWorkspaceSettings() {
        LanguageWorkspaceSettings.savePreferredSearchLanguage(preferredSearchLanguage)
        LanguageWorkspaceSettings.saveSearchEnglishFallback(searchEnglishFallback)
        LanguageWorkspaceSettings.savePreferredMapLabelLanguage(preferredMapLabelLanguage)
    }

    /// Restores sidebar vehicle fields from the last workspace snapshot.
    public func restoreVehicleWorkspace() {
        guard let snapshot = VehicleWorkspaceSettings.load() else { return }
        vehicleRegistration = snapshot.vehicleRegistration
        isHGVMode = snapshot.isHGVMode
        vehicleHeight = snapshot.vehicleHeight
        vehicleWeight = snapshot.vehicleWeight
        vehicleWidth = snapshot.vehicleWidth
        vehicleLength = snapshot.vehicleLength
        vehicleAxleWeight = snapshot.vehicleAxleWeight
        vehicleGroundClearance = snapshot.vehicleGroundClearance
        vehicleTurningRadius = snapshot.vehicleTurningRadius
        vehicleEnginePowerHP = snapshot.vehicleEnginePowerHP
        activeProfileName = snapshot.activeProfileName
        hazmatClass = snapshot.hazmatClassRaw.flatMap(HazmatClass.init(rawValue:))
        emissionClass = snapshot.emissionClassRaw.flatMap(EmissionClass.init(rawValue:))
        vehicleClassOverride = snapshot.vehicleClassOverrideRaw.flatMap(VehicleProfileClass.init(rawValue:))
        avoidNonCompliantLEZ = snapshot.avoidNonCompliantLEZ
        avoidResidential = snapshot.avoidResidential

        if let profileName = snapshot.activeProfileName {
            Task { @MainActor in
                let store = VehicleProfileStore()
                let profiles = await store.loadProfiles()
                if let profile = profiles.first(where: { $0.savedProfileName == profileName }) {
                    applyProfile(profile)
                }
            }
        }

        if !snapshot.vehicleRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { await refreshPlateLibrary() }
        }
    }

    /// Debounces persistence of sidebar vehicle workspace fields.
    public func scheduleVehicleWorkspacePersist() {
        vehicleWorkspacePersistTask?.cancel()
        vehicleWorkspacePersistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.persistVehicleWorkspace()
        }
    }

    /// Persists the current sidebar vehicle workspace snapshot.
    public func persistVehicleWorkspace() {
        let snapshot = VehicleWorkspaceSnapshot(
            vehicleRegistration: vehicleRegistration,
            isHGVMode: isHGVMode,
            vehicleHeight: vehicleHeight,
            vehicleWeight: vehicleWeight,
            vehicleWidth: vehicleWidth,
            vehicleLength: vehicleLength,
            vehicleAxleWeight: vehicleAxleWeight,
            vehicleGroundClearance: vehicleGroundClearance,
            vehicleTurningRadius: vehicleTurningRadius,
            vehicleEnginePowerHP: vehicleEnginePowerHP,
            activeProfileName: activeProfileName,
            hazmatClassRaw: hazmatClass?.rawValue,
            emissionClassRaw: emissionClass?.rawValue,
            vehicleClassOverrideRaw: vehicleClassOverride?.rawValue,
            avoidNonCompliantLEZ: avoidNonCompliantLEZ,
            avoidResidential: avoidResidential
        )
        VehicleWorkspaceSettings.save(snapshot)
    }

    /// Persists offline routing toggle.
    public func persistOfflineRoutingEnabled() {
        VehicleProfileStore.saveOfflineRoutingEnabled(offlineRoutingEnabled)
        updateCloudRoutingBanner()
    }

    /// Persists prefer-offline-routing toggle.
    public func persistPreferOfflineRouting() {
        VehicleProfileStore.savePreferOfflineRouting(preferOfflineRouting)
        updateCloudRoutingBanner()
    }

    /// Persists the graph tile CDN base URL and updates the offline store.
    public func persistTileServerURL() {
        let trimmed = tileServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        VehicleProfileStore.saveTileServerURL(trimmed)
        Task {
            await offlineGraphStore.setTileBaseURL(URL(string: trimmed))
        }
    }

    /// Persists local map style preference and refreshes the active style URL.
    public func persistUseLocalMapStyleWhenPackPresent() {
        VehicleProfileStore.saveUseLocalMapStyleWhenPackPresent(useLocalMapStyleWhenPackPresent)
        Task { await refreshOfflineMapPackStatus() }
    }

    /// Downloads the small Norfolk demo corridor (MVP). Full UK tiles should be pre-placed.
    public func downloadDemoOfflineCorridor() async {
        isDownloadingOfflineTiles = true
        offlineTileStatus = "Downloading demo corridor tiles…"
        defer { isDownloadingOfflineTiles = false }
        do {
            let box = DiskOfflineGraphStore.demoCorridorBoundingBox
            try await offlineGraphStore.ensureCorridor(
                minLat: box.minLat,
                maxLat: box.maxLat,
                minLon: box.minLon,
                maxLon: box.maxLon
            )
            let count = await offlineGraphStore.loadedTileCount()
            offlineTileStatus = "Demo corridor ready (\(count) tiles). Full UK: pre-place *.graphjson in Application Support/RouteFinder/tiles/"
        } catch {
            offlineTileStatus = error.localizedDescription
        }
    }

    /// Attempts to ensure a UK-wide corridor (may request many tiles — prefer pre-placed packs).
    public func downloadUKOfflineCorridor() async {
        isDownloadingOfflineTiles = true
        offlineTileStatus = "Ensuring UK corridor (large — prefer pre-placed tiles)…"
        defer { isDownloadingOfflineTiles = false }
        do {
            let box = DiskOfflineGraphStore.ukBoundingBox
            try await offlineGraphStore.ensureCorridor(
                minLat: box.minLat,
                maxLat: box.maxLat,
                minLon: box.minLon,
                maxLon: box.maxLon
            )
            let count = await offlineGraphStore.loadedTileCount()
            offlineTileStatus = "UK corridor loaded (\(count) tiles in memory/cache)."
        } catch {
            offlineTileStatus = error.localizedDescription + " Place tiles under Application Support/RouteFinder/tiles/ if download is unavailable."
        }
    }

    /// Refreshes offline map pack status and starts the local style server when enabled.
    public func refreshOfflineMapPackStatus() async {
        defer { mapStyleResolved = true }
        do {
            if let local = try await mapPackStore.prepareLocalStyleIfAvailable(enabled: useLocalMapStyleWhenPackPresent) {
                mapStyleURL = local.absoluteString
            } else {
                mapStyleURL = MapLibreConfiguration.openFreeMapStyleURL
            }
            let status = await mapPackStore.status(useLocalWhenPresent: useLocalMapStyleWhenPackPresent)
            offlineMapPackStatus = status.message
        } catch {
            mapStyleURL = MapLibreConfiguration.openFreeMapStyleURL
            offlineMapPackStatus = error.localizedDescription
        }
    }

    /// Disables local map-pack style and falls back to the online OpenFreeMap style.
    public func fallbackToOnlineMapStyle() async {
        useLocalMapStyleWhenPackPresent = false
        VehicleProfileStore.saveUseLocalMapStyleWhenPackPresent(false)
        await refreshOfflineMapPackStatus()
    }

    /// Transitions the advisory HOS duty mode and refreshes the HUD snapshot.
    public func transitionHosMode(_ mode: HosDutyMode, note: String? = nil) async {
        await hosAdvisoryCoordinator.transitionHosMode(mode, note: note)
    }

    /// Refreshes the HOS HUD snapshot from the clock.
    public func refreshHosSnapshot() async {
        await hosAdvisoryCoordinator.refreshHosSnapshot()
    }

    /// Recomputes the advisory “Can I drive now?” status from import + clock.
    public func refreshCanIDriveStatus() async {
        await hosAdvisoryCoordinator.refreshCanIDriveStatus()
    }

    /// Imports a driver-card JSON / DDD file and refreshes can-I-drive status.
    public func importTachoFile(url: URL) async {
        await hosAdvisoryCoordinator.importTachoFile(url: url)
    }

    /// Clears the imported tachograph summary.
    public func clearImportedTachoSummary() {
        Task { await hosAdvisoryCoordinator.clearImportedTachoSummary() }
    }

    /// Starts a new DVSA-style walkaround checklist for the current vehicle.
    public func startWalkaroundInspection() {
        let label = activeProfileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plate = vehicleRegistration.trimmingCharacters(in: .whitespacesAndNewlines)
        activeInspection = InspectionRecord(
            vehicleLabel: (label?.isEmpty == false ? label! : "HGV"),
            registrationPlate: plate.isEmpty ? nil : plate
        )
    }

    /// Persists the active walkaround inspection to disk.
    public func saveActiveInspection() async {
        guard var record = activeInspection else { return }
        guard record.isReadyToSave else { return }
        record.completedAt = Date()
        activeInspection = record
        do {
            try await inspectionStore.save(record)
            try await inspectionStore.enqueueSync(record)
            let summary = TripBriefInspectionSummary(record: record)
            latestInspectionSummary = summary
            refreshTripBriefShareText()
            if record.defectCount > 0 {
                await publishInspectionFleetHandoff(record: record, summary: summary)
            }
        } catch {
            errorMessage = "Could not save inspection: \(error.localizedDescription)"
        }
    }

    /// Rebuilds the HOS rest forecast for the current route using POIs and path durations.
    public func refreshHosForecast() async {
        await hosAdvisoryCoordinator.refreshHosForecast()
    }

    public func laybyPredictionInput(
        currentArcLengthMeters: Double,
        speedMps: Double
    ) -> LaybyPredictionInput {
        let hosRemainingContinuous = hosEnabled ? hosSnapshot?.remainingContinuousDriveSeconds : nil
        let hosRemainingDaily = hosEnabled ? hosSnapshot?.remainingDailyDriveSeconds : nil
        let trafficFactor = trafficRerouteAvailable
            ? LaybyPredictionEngine.defaultTrafficInflationFactor
            : nil
        return LaybyPredictionInput(
            candidates: upcomingLaybys,
            currentArcLengthMeters: currentArcLengthMeters,
            speedMps: speedMps,
            pathDurationsSeconds: hosAdvisoryCoordinator.hosPathDurationsSeconds(),
            pathArcLengthsMeters: hosAdvisoryCoordinator.hosPathArcLengthsMeters(),
            remainingContinuousDriveSeconds: hosRemainingContinuous,
            remainingDailyDriveSeconds: hosRemainingDaily,
            companyBreaks: activeDispatchCompanyBreaks,
            kineticStress: hosAdvisoryCoordinator.hosPathKineticStress(),
            trafficInflationFactor: trafficFactor,
            crowdReports: crowdReports
        )
    }

    /// Reorders intermediate stops for minimum travel time, then optionally recalculates the route.
    public func optimizeWaypointSequence(routeAfter: Bool = true) async {
        optimizationError = nil
        guard canOptimizeSequence else {
            optimizationError = "Resolve at least one intermediate stop before optimizing."
            return
        }

        guard let origin = originWaypoint.resolved?.routingCoordinate,
              let destination = destinationWaypoint.resolved?.routingCoordinate else {
            optimizationError = "Origin and destination must be resolved."
            return
        }

        let intermediateStops = viaWaypoints.compactMap(\.resolved?.routingCoordinate)
        guard intermediateStops.count == viaWaypoints.count else {
            optimizationError = "All intermediate stops must be resolved."
            return
        }

        isOptimizing = true
        defer { isOptimizing = false }

        let vehicleProfile = currentVehicleSpecificationProfile()
        let coordinator = RouteOptimizationCoordinator(orsAPIKey: orsAPIKey.isEmpty ? nil : orsAPIKey)
        let request = RouteOptimizationCoordinatorRequest(
            origin: origin,
            destination: destination,
            intermediateStops: intermediateStops,
            vehicleProfile: vehicleProfile,
            tier: .cloudOnly,
            autoRouteAfterOptimize: routeAfter
        )

        do {
            let result = try await coordinator.optimize(request: request)
            applyOptimizedIndices(result.optimizedStopIndices)
            if routeAfter {
                await calculateRoute()
            }
            if activeDispatchTripId != nil {
                await publishDispatchSnapshot(status: .optimized)
            }
        } catch {
            optimizationError = error.localizedDescription
        }
    }

    /// Applies a dispatched fleet trip onto the driver route model (3-stop MVP).
    public func applyDispatchedTrip(_ trip: FleetTrip) async {
        activeDispatchTripId = trip.id
        fleetVehicleId = trip.vehicleId
        activeDispatchCompanyBreaks = trip.companyBreaks
        if let profile = trip.vehicleProfile {
            applyProfile(profile)
            isHGVMode = true
        }

        let ordered = trip.stops.sorted { $0.sequence < $1.sequence }
        routeWaypoints = ordered.map { stop in
            let role: RouteWaypoint.Role = switch stop.role {
            case .origin: .origin
            case .via: .via
            case .destination: .destination
            }
            let coordinate = Coordinate(latitude: stop.latitude, longitude: stop.longitude)
            return RouteWaypoint(
                id: stop.id,
                role: role,
                rawText: stop.label,
                resolved: ResolvedEndpoint(
                    displayLabel: stop.label,
                    rawCoordinate: coordinate,
                    snappedCoordinate: coordinate
                )
            )
        }

        await publishDispatchSnapshot(status: .accepted)
        if canFindRoute {
            await findRoute()
        }
    }

    /// Seeds a demo 3-stop UK job and applies it to the driver device.
    public func acceptDemoFleetDispatch() async throws {
        try await fleetDispatchCoordinator.acceptDemoFleetDispatch()
    }

    /// Persists the fleet vehicle id from Settings text entry.
    public func saveFleetVehicleIdFromSettings() {
        fleetDispatchCoordinator.saveFleetVehicleIdFromSettings()
    }

    /// Persists fleet server settings from Settings text fields.
    public func saveFleetServerURLFromSettings() {
        fleetDispatchCoordinator.saveFleetServerURLFromSettings()
    }

    /// Replaces the active fleet store from current workspace settings.
    public func reloadFleetStore() {
        fleetDispatchCoordinator.reloadFleetStore()
    }

    /// Tests connectivity to the configured fleet HTTP server.
    public func testFleetServerConnection() async {
        await fleetDispatchCoordinator.testFleetServerConnection()
    }

    /// Scans the local network for fleet servers advertised via Bonjour.
    public func discoverFleetServersOnLAN() async {
        await fleetDispatchCoordinator.discoverFleetServersOnLAN()
    }

    /// Applies a Bonjour-discovered fleet server URL and enables remote sync.
    public func applyDiscoveredFleetServer(_ server: DiscoveredFleetServer) {
        fleetDispatchCoordinator.applyDiscoveredFleetServer(server)
    }

    /// Polls disk store for a newly pushed trip and applies it on the driver device.
    public func pollAndApplyFleetDispatch() async {
        await fleetDispatchCoordinator.pollAndApplyFleetDispatch()
    }

    /// Subscribes to fleet SSE events with fallback polling until the task is cancelled.
    public func startFleetDispatchListener() async {
        await fleetDispatchCoordinator.startFleetDispatchListener()
    }

    /// Publishes trip status + physics ETA for the dispatch console.
    public func publishDispatchSnapshot(
        status: FleetTripStatus? = nil,
        inspectionSummary: TripBriefInspectionSummary? = nil,
        inspectionReportPDFBase64: String? = nil
    ) async {
        await fleetDispatchCoordinator.publishDispatchSnapshot(
            status: status,
            inspectionSummary: inspectionSummary,
            inspectionReportPDFBase64: inspectionReportPDFBase64
        )
    }

    private func publishInspectionFleetHandoff(
        record: InspectionRecord,
        summary: TripBriefInspectionSummary
    ) async {
        await fleetDispatchCoordinator.publishInspectionFleetHandoff(record: record, summary: summary)
    }

    /// Returns the current trip as seen by dispatch (after driver snapshot publish).
    public func fetchDispatchTrip() async -> FleetTrip? {
        await fleetDispatchCoordinator.fetchDispatchTrip()
    }

    private func showFleetDispatchToast(_ message: String) {
        fleetDispatchCoordinator.showFleetDispatchToast(message)
    }

    /// Applies a pending traffic-aware alternate route when available.
    public func applyTrafficReroute() async {
        guard let alternate = pendingTrafficAlternate else { return }
        let preferences = routingPreferences()
        do {
            try await applyExternalRouteResponse(alternate, preferences: preferences)
            trafficRerouteAvailable = false
            pendingTrafficAlternate = nil
        } catch {
            errorMessage = "Could not apply traffic re-route: \(error.localizedDescription)"
        }
    }

    private func applyOptimizedIndices(_ indices: [Int]) {
        guard let origin = routeWaypoints.first,
              let destination = routeWaypoints.last else { return }
        let vias = viaWaypoints
        guard indices.count == vias.count,
              Set(indices) == Set(0..<vias.count) else { return }
        let ordered = indices.map { vias[$0] }
        routeWaypoints = [origin] + ordered + [destination]
    }

    private func currentVehicleSpecificationProfile() -> VehicleSpecificationProfile {
        let sidebarHP = VehicleDimensionParser.parseOptional(vehicleEnginePowerHP).map { Int($0.rounded()) }

        if let resolved = resolvedSpecificationProfile {
            guard let sidebarHP, sidebarHP > 0, sidebarHP != resolved.enginePowerHorsepower else {
                return resolved
            }
            return VehicleSpecificationProfile(
                registrationMark: resolved.registrationMark,
                vehicleClass: resolved.vehicleClass,
                make: resolved.make,
                model: resolved.model,
                grossWeightKilograms: resolved.grossWeightKilograms,
                lengthMeters: resolved.lengthMeters,
                widthMeters: resolved.widthMeters,
                heightMeters: resolved.heightMeters,
                axleCount: resolved.axleCount,
                enginePowerHorsepower: sidebarHP,
                source: resolved.source
            )
        }

        let vehicleClass: VehicleProfileClass = isHGVMode ? .heavyGoodsVehicle : .passengerCar
        let weightKg = (VehicleDimensionParser.parseOptional(vehicleWeight) ?? 0) * 1000.0
        let length = VehicleDimensionParser.parseOptional(vehicleLength)
        let width = VehicleDimensionParser.parseOptional(vehicleWidth)
        let height = VehicleDimensionParser.parseOptional(vehicleHeight)
        let axleCount = Int(VehicleDimensionParser.parseOptional(vehicleAxleCount) ?? 0)

        var profile = VehicleSpecificationProfile.routingDefault(
            vehicleClass: vehicleClass,
            grossWeightKilograms: weightKg > 0 ? weightKg : nil,
            registrationMark: vehicleRegistration
        )

        if length != nil || width != nil || height != nil || axleCount > 0 || sidebarHP != nil {
            profile = VehicleSpecificationProfile(
                registrationMark: profile.registrationMark,
                vehicleClass: vehicleClass,
                make: profile.make,
                model: profile.model,
                grossWeightKilograms: weightKg > 0 ? weightKg : profile.grossWeightKilograms,
                lengthMeters: length ?? profile.lengthMeters,
                widthMeters: width ?? profile.widthMeters,
                heightMeters: height ?? profile.heightMeters,
                axleCount: axleCount > 0 ? axleCount : profile.axleCount,
                enginePowerHorsepower: sidebarHP ?? profile.enginePowerHorsepower,
                source: profile.source
            )
        }

        return profile
    }

    private func applyOptimizedSequence(_ sequence: [CLLocationCoordinate2D]) {
        guard sequence.count >= 2,
              let origin = routeWaypoints.first,
              let destination = routeWaypoints.last else { return }

        let optimizedVias = Array(sequence.dropFirst().dropLast())
        let vias = viaWaypoints
        guard optimizedVias.count == vias.count else { return }

        var remaining = vias
        var ordered: [RouteWaypoint] = []
        for coordinate in optimizedVias {
            if let index = remaining.firstIndex(where: { waypoint in
                guard let resolved = waypoint.resolved else { return false }
                return abs(resolved.routingCoordinate.latitude - coordinate.latitude) < 1e-6
                    && abs(resolved.routingCoordinate.longitude - coordinate.longitude) < 1e-6
            }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        if ordered.count == vias.count {
            routeWaypoints = [origin] + ordered + [destination]
        }
    }

    private var configuredEnginePowerHP: Double {
        if let parsed = VehicleDimensionParser.parseOptional(vehicleEnginePowerHP) {
            return parsed
        }
        if let profileHP = resolvedSpecificationProfile?.enginePowerHorsepower, profileHP > 0 {
            return Double(profileHP)
        }
        return isHGVMode ? RouteDynamicsPhysics.defaultEnginePowerHP : 150
    }

    /// Pushes sidebar HP edits into the live simulation profile when a route is active.
    public func refreshSimulationPowerFromSidebar() async {
        guard !routeCoordinates.isEmpty else { return }
        let physics = resolvedVehiclePhysics()
        await simulationEngine.configureVehicleSpecification(
            currentVehicleSpecificationProfile(),
            vehicle: resolvedVehicleProfile(),
            minimumTurnRadiusMeters: physics.turningRadiusMeters
        )
    }

    public func beginPinMode(for waypointID: UUID) {
        interactionMode = .setPin(waypointID)
        activePinTarget = .waypoint(waypointID)
    }

    public func cancelPinMode() {
        interactionMode = .navigate
        activePinTarget = .none
    }

    public func applyHGVPreset() {
        applyProfile(.ukArtic)
        avoidResidential = true
        isHGVMode = true
    }

    public func updateMapViewport(center: CLLocationCoordinate2D) {
        mapViewportCenter = Coordinate(latitude: center.latitude, longitude: center.longitude)
    }

    /// Persists the HeiGIT API key to the on-disk vault.
    public func persistORSAPIKey() {
        let value = orsAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        orsAPIKey = value
        hasORSAPIKey = true
        orsAPIKeyDraft = ""
        persistSecret(value, kind: .ors)
        updateCloudRoutingBanner()
    }

    /// Recenters the map on resolved endpoints or the default UK viewport.
    public func recenterMap() {
        if simulationEngine.isRunning, let coordinate = simulationEngine.currentCoordinate {
            mapBridge?.resumeTracking(at: coordinate)
            mapRegion = MapRegion(
                center: coordinate,
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
            return
        }
        if !routeCoordinates.isEmpty {
            #if os(macOS)
            fitMapToRoute(padding: .macOSRouteFit)
            #else
            fitMapToRoute()
            #endif
            return
        }
        if let start = originWaypoint.resolved {
            mapRegion = MapRegion(
                center: CLLocationCoordinate2D(
                    latitude: start.snappedCoordinate.latitude,
                    longitude: start.snappedCoordinate.longitude
                ),
                latitudeDelta: 0.08,
                longitudeDelta: 0.08
            )
            return
        }
        mapRegion = MapRegion(
            center: CLLocationCoordinate2D(
                latitude: MapDefaults.ukCenter.latitude,
                longitude: MapDefaults.ukCenter.longitude
            ),
            latitudeDelta: 0.8,
            longitudeDelta: 0.8
        )
    }

    #if os(iOS)
    /// Starts GPS updates for follow-mode navigation.
    public func startLocationServicesIfNeeded() async {
        do {
            let headingLock = mapBridge?.cameraMode == .lockHeading
            try await navigationCoordinator.startGPSNavigation(enableHeading: headingLock)
            isNavigationActive = true
        } catch {
            // Authorization may still be pending; provider will start when granted.
        }
    }

    /// Stops follow-mode navigation and voice prompts.
    public func stopNavigation() {
        isFollowModeEnabled = false
        isNavigationActive = false
        navigationCoordinator.stopNavigation()
        voiceGuidanceCoordinator.teardown()
    }
    #endif

    public func suggestions(for waypointID: UUID) -> [GeocodeSuggestion] {
        searchSuggestions[waypointID] ?? []
    }

    public func searchFeedback(for waypointID: UUID) -> String? {
        searchFeedback[waypointID]
    }

    public func updateSearchSuggestions(for waypointID: UUID, query: String) {
        guard let index = routeWaypoints.firstIndex(where: { $0.id == waypointID }),
              routeWaypoints[index].rawText == query else { return }

        searchTasks[waypointID]?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let waypoint = routeWaypoints[index]
        if waypoint.isResolved, waypoint.rawText.trimmingCharacters(in: .whitespaces) == trimmed {
            searchSuggestions[waypointID] = []
            searchFeedback[waypointID] = nil
            return
        }

        guard trimmed.count >= 2 else {
            searchSuggestions[waypointID] = []
            searchFeedback[waypointID] = nil
            invalidateResolutionIfTextChanged(for: waypointID, newText: trimmed)
            return
        }

        invalidateResolutionIfTextChanged(for: waypointID, newText: trimmed)

        searchTasks[waypointID] = Task {
            let outcome = await performGeocodeSearch(query: trimmed)

            guard !Task.isCancelled else { return }
            guard routeWaypoints.first(where: { $0.id == waypointID })?.rawText == query else { return }
            searchSuggestions[waypointID] = outcome.suggestions
            searchFeedback[waypointID] = outcome.feedback
        }
    }

    public func addWaypoint() {
        let via = RouteWaypoint(role: .via)
        routeWaypoints.insert(via, at: routeWaypoints.count - 1)
    }

    public func removeWaypoint(id: UUID) {
        guard let index = routeWaypoints.firstIndex(where: { $0.id == id }),
              routeWaypoints[index].role == .via else { return }
        routeWaypoints.remove(at: index)
        searchSuggestions.removeValue(forKey: id)
        searchFeedback.removeValue(forKey: id)
        searchTasks[id]?.cancel()
        searchTasks.removeValue(forKey: id)
    }

    public func setLocation(_ coordinate: Coordinate, label: String, for waypointID: UUID) async {
        await applyCoordinate(coordinate, label: label, waypointID: waypointID)
    }

    public func applySuggestion(_ suggestion: GeocodeSuggestion, for waypointID: UUID) async {
        let locked = Waypoint(suggestion)
        await applyCoordinate(
            locked.coordinate,
            label: suggestion.subtitle,
            waypointID: waypointID
        )
    }

    public func setPin(at coordinate: Coordinate, for waypointID: UUID) async {
        let label = await locationResolver.reverseGeocode(coordinate: coordinate)
        await applyCoordinate(coordinate, label: label, waypointID: waypointID)
    }

    public func handleMapClick(at coordinate: Coordinate) async {
        if case .setPin(let waypointID) = interactionMode {
            await setPin(at: coordinate, for: waypointID)
        }
    }

    public func handleContextAction(_ action: MapContextAction, at coordinate: Coordinate) async {
        switch action {
        case .setStart:
            await setPin(at: coordinate, for: originWaypoint.id)
        case .setEnd:
            await setPin(at: coordinate, for: destinationWaypoint.id)
        case .addStop:
            addWaypoint()
            let insertIndex = routeWaypoints.count - 2
            guard routeWaypoints.indices.contains(insertIndex) else { return }
            await setPin(at: coordinate, for: routeWaypoints[insertIndex].id)
        }
    }

    public func resolveDisambiguation(_ suggestion: GeocodeSuggestion) async {
        guard let pending = pendingDisambiguation else { return }
        pendingDisambiguation = nil
        await applySuggestion(suggestion, for: pending.waypointID)
    }

    public func cancelDisambiguation() {
        pendingDisambiguation = nil
    }

    /// Geocodes unresolved endpoints then calculates the route.
    public func findRoute() async {
        errorMessage = nil

        if !originWaypoint.isResolved {
            let ok = await geocodeWaypoint(id: originWaypoint.id)
            if !ok { return }
        }
        if !destinationWaypoint.isResolved {
            if pendingDisambiguation != nil { return }
            let ok = await geocodeWaypoint(id: destinationWaypoint.id)
            if !ok { return }
        }
        if pendingDisambiguation != nil { return }

        for via in viaWaypoints where !via.isResolved && !via.rawText.trimmingCharacters(in: .whitespaces).isEmpty {
            let ok = await geocodeWaypoint(id: via.id)
            if !ok { return }
            if pendingDisambiguation != nil { return }
        }

        if autoOptimizeOnRouteFind, canOptimizeSequence {
            await optimizeWaypointSequence(routeAfter: false)
        }

        await calculateRoute()
    }

    public func recalculateIfReady() async {
        routePlanningCoordinator.recalculateIfReady(
            originResolved: originWaypoint.isResolved,
            destinationResolved: destinationWaypoint.isResolved
        )
    }

    public func calculateRoute() async {
        isCalculating = true
        errorMessage = nil
        routeFailure = nil
        simulationEngine.stop()
        updateCloudRoutingBanner()
        defer {
            isCalculating = false
            updateCloudRoutingBanner()
        }

        guard originWaypoint.resolved != nil, destinationWaypoint.resolved != nil else {
            errorMessage = "Enter a start and destination"
            result = nil
            clearRouteGeometry()
            return
        }

        let preferences = routingPreferences()

        do {
            try await calculateHybridRoute(preferences: preferences)
            hasCompletedCloudRoute = true
            routeFailure = nil
            updateCloudRoutingBanner()
        } catch {
            routePlanningCoordinator.presentRouteError(error, preferences: preferences)
        }
    }

    // MARK: - Private

    @discardableResult
    func geocodeWaypoint(id: UUID) async -> Bool {
        guard let index = routeWaypoints.firstIndex(where: { $0.id == id }) else { return false }
        let waypoint = routeWaypoints[index]
        if waypoint.isResolved, waypoint.coordinate != nil {
            return true
        }

        let trimmed = routeWaypoints[index].rawText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a start and destination"
            return false
        }

        let results = await performGeocodeSearch(query: trimmed).suggestions

        guard !results.isEmpty else {
            errorMessage = "No places found for “\(trimmed)”"
            return false
        }

        if results.count == 1 {
            let pick = results[0]
            await applySuggestion(pick, for: id)
            return routeWaypoints.first(where: { $0.id == id })?.isResolved == true
        }

        pendingDisambiguation = GeocodeDisambiguationRequest(
            query: trimmed,
            waypointID: id,
            candidates: results
        )
        return false
    }

    private func applyCoordinate(_ coordinate: Coordinate, label: String, waypointID: UUID) async {
        let displayLabel = label.trimmingCharacters(in: .whitespaces)

        commitWaypoint(
            id: waypointID,
            endpoint: ResolvedEndpoint(
                displayLabel: displayLabel,
                rawCoordinate: coordinate,
                snappedCoordinate: coordinate,
                nodeID: nil,
                snapDistanceMeters: nil,
                roadName: nil
            )
        )
    }

    func commitWaypoint(id: UUID, endpoint: ResolvedEndpoint) {
        guard let index = routeWaypoints.firstIndex(where: { $0.id == id }) else { return }
        let displayLabel = endpoint.displayLabel.trimmingCharacters(in: .whitespaces)
        routeWaypoints[index].resolved = endpoint
        routeWaypoints[index].rawText = displayLabel
        searchTasks[id]?.cancel()
        searchTasks.removeValue(forKey: id)
        searchSuggestions[id] = []
        searchFeedback[id] = nil
        cancelPinMode()
        Task { await recalculateIfReady() }
    }

    private func calculateHybridRoute(preferences: RoutingPreferences) async throws {
        guard let start = originWaypoint.resolved, let end = destinationWaypoint.resolved else {
            throw RoutingError.invalidInput("Enter a start and destination")
        }

        let waypointCoords = viaWaypoints
            .filter { !$0.rawText.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { waypoint -> RoutingCoordinate? in
                waypoint.waypoint?.routingCoordinate
            }

        let request = ExternalRouteRequest(
            origin: start.waypoint.routingCoordinate,
            destination: end.waypoint.routingCoordinate,
            waypoints: waypointCoords,
            vehicle: preferences.vehicle,
            preferences: preferences,
            avoidPolygons: lezAvoidPolygons(
                origin: start.waypoint.routingCoordinate,
                destination: end.waypoint.routingCoordinate
            )
        )

        let offlineAvailable = await offlineGraphStore.hasOfflineTilesAvailable()
        let policy = HybridRoutingPolicy(
            preferOfflineRouting: preferOfflineRouting,
            offlineRoutingEnabled: offlineRoutingEnabled,
            hasORSAPIKey: hasORSAPIKey,
            hasOfflineTilesAvailable: offlineAvailable
        )

        if policy.lacksAnyRoutingBackend {
            throw OfflineGraphStoreError.noTilesAvailable
        }

        // Offline primary (tiles actually available).
        if policy.preferredSource == .offlineTiles {
            let (searchResult, coordinates, _) = try await planner.calculateHybridRoute(
                request: request,
                policy: policy,
                offlineStore: offlineGraphStore
            )
            applyOfflineRouteResult(searchResult, coordinates: coordinates, preferences: preferences)
            return
        }

        do {
            try await calculateExternalRoute(preferences: preferences)
        } catch {
            guard policy.shouldFallbackToOfflineOnORSFailure else { throw error }
            let (searchResult, coordinates, _) = try await planner.calculateHybridRoute(
                request: request,
                policy: HybridRoutingPolicy(
                    preferOfflineRouting: true,
                    offlineRoutingEnabled: true,
                    hasORSAPIKey: false,
                    hasOfflineTilesAvailable: offlineAvailable
                ),
                offlineStore: offlineGraphStore
            )
            applyOfflineRouteResult(searchResult, coordinates: coordinates, preferences: preferences)
        }
    }

    private func applyOfflineRouteResult(
        _ searchResult: SearchResult,
        coordinates: [Coordinate],
        preferences: RoutingPreferences
    ) {
        let heuristicInstructions = LaneGuidanceEnricher.enrichWithHeuristics(
            instructions: searchResult.turnInstructions
        )
        let resultWithHeuristics = SearchResult(
            path: searchResult.path,
            totalDistance: searchResult.totalDistance,
            totalTime: searchResult.totalTime,
            nodesVisited: searchResult.nodesVisited,
            runtime: searchResult.runtime,
            explanation: searchResult.explanation,
            turnInstructions: heuristicInstructions,
            metrics: searchResult.metrics
        )

        result = resultWithHeuristics
        let canonical = RouteGeometryCanonicalizer.process(coordinates, speedLimitSource: nil)
        routeGeometry = .polyline(encoded: nil, precision: 6, coordinates: coordinates)
        routeEncodedPolyline = nil
        routeEncodedPolylinePrecision = 6
        routeCoordinates = canonical.displayCoordinates
        routeCumulativeLengths = navigationCoordinatorDisplayLengths(canonical)

        navigationCoordinator.loadRoute(
            canonical: canonical,
            turnInstructions: resultWithHeuristics.turnInstructions,
            staticTotalTimeSeconds: resultWithHeuristics.metrics.totalTime,
            webRoutingETASeconds: resultWithHeuristics.metrics.totalTime
        )

        let physics = resolvedVehiclePhysics()
        simulationEngine.configure(
            route: coordinates,
            environmentalContext: environmentalContext,
            vehicle: resolvedVehicleProfile(),
            totalDuration: resultWithHeuristics.metrics.totalTime,
            enginePowerHP: configuredEnginePowerHP,
            maneuvers: [],
            turnInstructions: resultWithHeuristics.turnInstructions,
            isPassengerCar: !preferences.isHGVMode,
            tomTomAPIKey: tomTomAPIKey.isEmpty ? nil : tomTomAPIKey,
            vehicleSpecificationProfile: currentVehicleSpecificationProfile(),
            canonicalGeometry: canonical,
            minimumTurnRadiusMeters: physics.turningRadiusMeters,
            applyTrafficToSimulation: applyTrafficToSimulation
        )
        cloudRoutingBanner = "Offline tiled routing"
        fitMapToRoute()
        scheduleLaneGuidanceEnrichment(
            instructions: heuristicInstructions,
            coordinates: coordinates,
            queryOverpass: false
        )
    }

    private func calculateExternalRoute(preferences: RoutingPreferences) async throws {
        guard let start = originWaypoint.resolved, let end = destinationWaypoint.resolved else {
            throw RoutingError.invalidInput("Enter a start and destination")
        }

        let waypointCoords = viaWaypoints
            .filter { !$0.rawText.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { waypoint -> RoutingCoordinate? in
                waypoint.waypoint?.routingCoordinate
            }

        let request = ExternalRouteRequest(
            origin: start.waypoint.routingCoordinate,
            destination: end.waypoint.routingCoordinate,
            waypoints: waypointCoords,
            vehicle: preferences.vehicle,
            preferences: preferences,
            avoidPolygons: lezAvoidPolygons(
                origin: start.waypoint.routingCoordinate,
                destination: end.waypoint.routingCoordinate
            )
        )
        lastExternalRouteRequest = request

        let externalPlanner = try makeExternalPlanner()
        let (_, response) = try await externalPlanner.calculateExternalRoute(request: request)
        try await applyExternalRouteResponse(response, preferences: preferences)
        scheduleTrafficRerouteEvaluation(request: request, original: response)
    }

    /// ORS avoid rings for non-compliant UK LEZ / CAZ zones (nil when empty / disabled).
    ///
    /// Long hauls omit avoids (ORS rejects avoid areas when route distance exceeds ~150 km).
    private func lezAvoidPolygons(
        origin: RoutingCoordinate,
        destination: RoutingCoordinate
    ) -> [[[Double]]]? {
        RoutePlanningCoordinator.lezAvoidPolygons(
            emissionClass: emissionClass,
            avoidEnabled: avoidNonCompliantLEZ,
            origin: origin,
            destination: destination
        )
    }

    /// Applies an external route response to map, simulation, and HGV living-layer hooks.
    private func applyExternalRouteResponse(
        _ response: ExternalRouteResponse,
        preferences: RoutingPreferences
    ) async throws {
        let heuristicInstructions = RoutePlanningCoordinator.heuristicTurnInstructions(from: response)
        let searchResult = RoutePlanningCoordinator.searchResult(
            from: response,
            preferences: preferences,
            turnInstructions: heuristicInstructions
        )

        result = searchResult
        let canonical = RouteGeometryCanonicalizer.process(
            response.coordinates,
            speedLimitSource: response.speedLimitSource
        )
        routeGeometry = .polyline(
            encoded: response.encodedPolyline,
            precision: response.polylinePrecision,
            coordinates: response.coordinates
        )
        routeEncodedPolyline = response.encodedPolyline
        routeEncodedPolylinePrecision = response.polylinePrecision
        routeCoordinates = canonical.displayCoordinates
        routeCumulativeLengths = navigationCoordinatorDisplayLengths(canonical)

        navigationCoordinator.loadRoute(
            canonical: canonical,
            turnInstructions: searchResult.turnInstructions,
            staticTotalTimeSeconds: searchResult.metrics.totalTime,
            webRoutingETASeconds: searchResult.metrics.totalTime
        )

        let physics = resolvedVehiclePhysics()
        simulationEngine.configure(
            route: response.coordinates,
            environmentalContext: environmentalContext,
            vehicle: resolvedVehicleProfile(),
            totalDuration: searchResult.metrics.totalTime,
            enginePowerHP: configuredEnginePowerHP,
            maneuvers: response.maneuvers,
            turnInstructions: searchResult.turnInstructions,
            isPassengerCar: !preferences.isHGVMode,
            tomTomAPIKey: tomTomAPIKey.isEmpty ? nil : tomTomAPIKey,
            vehicleSpecificationProfile: currentVehicleSpecificationProfile(),
            canonicalGeometry: canonical,
            minimumTurnRadiusMeters: physics.turningRadiusMeters,
            applyTrafficToSimulation: applyTrafficToSimulation
        )
        scheduleFitMapToRoute()
        loadLaybysAlongRoute(response.coordinates)
        loadTruckPoisAlongRoute(response.coordinates)
        loadRoadworksAlongRoute(response.coordinates)
        refreshRestrictionAnnouncements(for: response.coordinates)
        estimatePhysicsDuration(for: searchResult, canonical: canonical)
        if hosEnabled {
            Task { await refreshHosForecast() }
        }
        scheduleLaneGuidanceEnrichment(
            instructions: heuristicInstructions,
            coordinates: response.coordinates
        )
    }

    private func scheduleLaneGuidanceEnrichment(
        instructions: [TurnInstruction],
        coordinates: [Coordinate],
        queryOverpass: Bool = true
    ) {
        routePlanningCoordinator.scheduleLaneGuidanceEnrichment(
            instructions: instructions,
            coordinates: coordinates,
            queryOverpass: queryOverpass
        )
    }

    public func applyLaneGuidanceEnrichment(_ instructions: [TurnInstruction]) {
        guard let current = result else { return }
        result = SearchResult(
            path: current.path,
            totalDistance: current.totalDistance,
            totalTime: current.totalTime,
            nodesVisited: current.nodesVisited,
            runtime: current.runtime,
            explanation: current.explanation,
            turnInstructions: instructions,
            metrics: current.metrics
        )
        navigationCoordinator.updateTurnInstructions(instructions)
        simulationEngine.updateTurnInstructions(instructions)
        refreshActiveLaneGuidance()
    }

    /// Optionally samples TomTom along the route and prepares an avoid-polygon alternate.
    private func scheduleTrafficRerouteEvaluation(
        request: ExternalRouteRequest,
        original: ExternalRouteResponse
    ) {
        routePlanningCoordinator.scheduleTrafficRerouteEvaluation(
            inputs: TrafficRerouteScheduleInputs(
                request: request,
                original: original,
                avoidTrafficDelaysWhenRouting: avoidTrafficDelaysWhenRouting,
                tomTomAPIKey: tomTomAPIKey,
                orsAPIKey: orsAPIKey,
                vehicleProfile: currentVehicleSpecificationProfile(),
                measurementSystem: displayMeasurementSystem
            )
        )
    }

    private func estimatePhysicsDuration(
        for searchResult: SearchResult,
        canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry
    ) {
        routeSimulationCoordinator.estimatePhysicsDuration(for: searchResult, canonical: canonical)
    }

    /// Runs a full pre-trip physics rehearsal and publishes a shareable predictive trip brief.
    public func rehearseRoute() {
        guard result != nil, routeCoordinates.count >= 3 else { return }
        routeSimulationCoordinator.rehearseRoute()
    }

    /// Refreshes share text from the current predictive telemetry report, if any.
    public func refreshTripBriefShareText() {
        let context = tripBriefContext()
        guard context.predictiveReport != nil
            || context.physicsETASeconds != nil
            || !context.stops.isEmpty
            || context.latestInspectionSummary != nil else {
            tripBriefShareText = nil
            return
        }
        tripBriefShareText = TripBriefFormatter.plainText(from: context)
    }

    /// Builds the unified shareable trip brief from current driver state.
    public func tripBriefContext() -> TripBriefContext {
        let stops = routeWaypoints.compactMap { waypoint -> TripBriefStop? in
            let label = waypoint.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return TripBriefStop(
                label: label,
                role: waypoint.role.rawValue,
                coordinate: waypoint.coordinate
            )
        }
        let status: String? = activeDispatchTripId.map { _ in
            lastPublishedFleetSnapshot?.status.rawValue.capitalized ?? "Dispatched"
        }
        let coordinates = routeCoordinates.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        return TripBriefContext(
            predictiveReport: simulationEngine.telemetryReport,
            hosForecast: hosEnabled ? hosForecast : nil,
            laybyAdvisory: laybyAdvisory,
            stops: stops,
            companyBreaks: activeDispatchCompanyBreaks,
            physicsETASeconds: journeyPhysicsETASeconds,
            vehicleLabel: tripBriefVehicleLabel(),
            tripStatus: status,
            routeCoordinates: coordinates,
            latestInspectionSummary: latestInspectionSummary
        )
    }

    private func tripBriefVehicleLabel() -> String? {
        if let name = resolvedVehicleProfile().savedProfileName, !name.isEmpty {
            return name
        }
        if !vehicleRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return vehicleRegistration
        }
        return isHGVMode ? "HGV" : nil
    }

    private func handleKineticUIState(_ uiState: SimulationUIState) {
        routeSimulationCoordinator.handleKineticUIState(uiState)
    }

    /// Fetches layby POIs along the route and configures the layby advisor.
    public func loadLaybysAlongRoute(_ coordinates: [Coordinate]) {
        laybyLoadTask?.cancel()
        laybyAdvisory = nil
        routeSimulationCoordinator.clearLastAnnouncedLayby()
        hazardNavigationCoordinator.resetRouteHazardState(state: hazardState)
        upcomingLaybys = []
        isLoadingLaybys = true

        laybyLoadTask = Task { @MainActor in
            defer { isLoadingLaybys = false }
            do {
                let stops = try await laybyCatalogService.laybysAlongRoute(coordinates)
                guard !Task.isCancelled else { return }
                await laybyAdvisor.configure(candidates: stops)
                upcomingLaybys = stops
                await refreshLaybyAdvisory()
            } catch {
                guard !Task.isCancelled else { return }
                upcomingLaybys = []
                laybyAdvisory = nil
            }
        }
    }

    /// Searches truck fuel / parking / weighbridges within 20 miles ahead along the route.
    public func loadTruckPoisAlongRoute(_ coordinates: [Coordinate]) {
        truckPoiLoadTask?.cancel()
        upcomingTruckPois = []
        isLoadingTruckPois = true

        truckPoiLoadTask = Task { @MainActor in
            defer { isLoadingTruckPois = false }
            do {
                let profile = VehiclePhysicalVector.from(legacy: resolvedVehicleProfile())
                let fromArc = simulationEngine.currentArcLengthMeters
                let pois = try await truckPoiRepository.queryAlongRoute(
                    route: coordinates,
                    kinds: [.highFlowDiesel, .weighStation, .overnightSecureParking, .layby],
                    aheadMeters: TruckPoiSearchDefaults.twentyMilesMeters,
                    fromArcLengthMeters: fromArc,
                    corridorHalfWidthMeters: TruckPoiSearchDefaults.corridorHalfWidthMeters,
                    profile: profile
                )
                guard !Task.isCancelled else { return }
                upcomingTruckPois = ParkingOccupancyPrior.adjust(
                    pois: pois,
                    reports: crowdReports
                )
                if hosEnabled {
                    await refreshHosForecast()
                }
            } catch {
                guard !Task.isCancelled else { return }
                upcomingTruckPois = []
            }
        }
    }

    /// Searches OSM roadworks / construction nodes within ~20 miles ahead along the route.
    public func loadRoadworksAlongRoute(_ coordinates: [Coordinate]) {
        hazardNavigationCoordinator.loadRoadworksAlongRoute(
            state: hazardState,
            coordinates: coordinates,
            currentArcLengthMeters: simulationEngine.currentArcLengthMeters
        )
    }

    /// Refreshes LEZ / restriction / driving-ban announcements for the given route coordinates.
    public func refreshRestrictionAnnouncements(for coordinates: [Coordinate]) {
        let destination = destinationWaypoint.resolved.map {
            Coordinate(
                latitude: $0.waypoint.routingCoordinate.latitude,
                longitude: $0.waypoint.routingCoordinate.longitude
            )
        }
        let lez = UKLowEmissionZoneCatalog.announcements(
            along: coordinates,
            emissionClass: emissionClass,
            avoidEnabled: avoidNonCompliantLEZ,
            destination: destination
        )
        let bans = UKDrivingBanCatalog.announcements(along: coordinates, at: Date())
        restrictionAnnouncements = (lez + bans).sorted {
            $0.distanceAlongRouteMeters < $1.distanceAlongRouteMeters
        }
        activeRestrictionAnnouncement = restrictionAnnouncements.first
    }

    /// Convenience: truck fuel sites within 20 miles ahead on the active route.
    public var truckFuelWithin20Miles: [TruckPoi] {
        upcomingTruckPois.filter { $0.kind == .highFlowDiesel }
    }

    /// Refreshes the layby advisory from the current simulation position.
    public func refreshLaybyAdvisory() async {
        if hosEnabled {
            hosSnapshot = await hosClock.snapshot()
        }
        let arcLength = currentRouteArcLengthMeters
        let speedMps = max(currentRouteSpeedMps, 1.0)
        let input = laybyPredictionInput(
            currentArcLengthMeters: arcLength,
            speedMps: speedMps
        )
        await laybyAdvisor.updatePredictionContext(input)
        laybyAdvisory = await laybyAdvisor.upcomingAdvisory(
            currentArcLengthMeters: arcLength,
            speedMps: speedMps,
            predictionInput: input
        )
        routeSimulationCoordinator.processLaybyVoiceAlertIfNeeded()
        refreshTripBriefShareText()
    }

    /// Refreshes the nearest closure/traffic hazard ahead on the active route.
    public func refreshHazardAheadAnnouncement() {
        hazardNavigationCoordinator.refreshHazardAheadAnnouncement(
            state: hazardState,
            context: hazardNavigationContext()
        )
    }

    /// Polls TomTom flow ahead of the vehicle when keyed and throttled.
    public func sampleTomTomHazardAheadIfNeeded() {
        guard let context = hazardNavigationContext() else { return }
        hazardNavigationCoordinator.sampleTomTomHazardAheadIfNeeded(
            state: hazardState,
            context: context
        )
    }

    /// Updates the nearest roadworks site ahead from the cached corridor query.
    public func refreshActiveRoadworksAhead() {
        hazardNavigationCoordinator.refreshActiveRoadworksAhead(
            state: hazardState,
            currentArcLengthMeters: currentRouteArcLengthMeters
        )
    }

    /// Arc length along the active route for HUD distance labels.
    public var currentRouteArcLengthForDisplay: Double {
        currentRouteArcLengthMeters
    }

    private var currentRouteArcLengthMeters: Double {
        if simulationEngine.isRunning {
            return simulationEngine.currentArcLengthMeters
        }
        if let arcLength = navigationCoordinator.session.progressSnapshot?.arcLengthMeters {
            return arcLength
        }
        return simulationEngine.currentArcLengthMeters
    }

    private var currentRouteSpeedMps: Double {
        if simulationEngine.isRunning {
            return max(simulationEngine.currentSpeedKmh / 3.6, 1.0)
        }
        if let speedMps = navigationCoordinator.session.latestPosition?.speedMps, speedMps > 0 {
            return speedMps
        }
        return max(simulationEngine.currentSpeedKmh / 3.6, 1.0)
    }

    /// Break Now: rank nearest layby ahead and center the map on the top candidate.
    public func findBreakNow() async {
        await routeSimulationCoordinator.findBreakNow()
    }

    /// Centers the map on a layby stop coordinate.
    public func focusMapOnLayby(_ advisory: LaybyAdvisory) {
        let coordinate = CLLocationCoordinate2D(
            latitude: advisory.stop.coordinate.latitude,
            longitude: advisory.stop.coordinate.longitude
        )
        mapBridge?.resumeTracking(at: coordinate)
        mapRegion = MapRegion(center: coordinate, latitudeDelta: 0.012, longitudeDelta: 0.012)
    }

    /// Marks the current layby as full, records an on-device occupancy report, and advances to the next candidate.
    public func markCurrentLaybyFull() {
        Task { @MainActor in
            if let advisory = laybyAdvisory {
                await submitLaybyOccupancyReport(stop: advisory.stop, kind: .full)
            }
            let arcLength = simulationEngine.currentArcLengthMeters
            let speedMps = max(simulationEngine.currentSpeedKmh / 3.6, 1.0)
            let input = laybyPredictionInput(
                currentArcLengthMeters: arcLength,
                speedMps: speedMps
            )
            _ = await laybyAdvisor.markCurrentFull(
                currentArcLengthMeters: arcLength,
                speedMps: speedMps,
                predictionInput: input
            )
            routeSimulationCoordinator.clearLastAnnouncedLayby()
            await refreshLaybyAdvisory()
            showFleetDispatchToast(LaybyAlertFormatter.nextLaybyToast(next: laybyAdvisory))
        }
    }

    /// Records that the recommended layby still has spaces and refreshes the advisory with the new prior.
    public func markCurrentLaybyHasSpaces() {
        Task { @MainActor in
            guard let advisory = laybyAdvisory else { return }
            await submitLaybyOccupancyReport(stop: advisory.stop, kind: .spacesAvailable)
            await refreshLaybyAdvisory()
        }
    }

    private func hydrateCrowdReportsFromDisk() async {
        await hazardNavigationCoordinator.hydrateCrowdReportsFromDisk(
            state: hazardState,
            hasActiveRoute: result != nil,
            context: hazardNavigationContext()
        )
        if !upcomingTruckPois.isEmpty {
            upcomingTruckPois = PoiConfidenceAdjuster.adjust(pois: upcomingTruckPois, reports: crowdReports)
        }
    }

    private func submitLaybyOccupancyReport(stop: LaybyStop, kind: LaybyOccupancyReport.Kind) async {
        let report = LaybyOccupancyReport.make(
            stop: stop,
            kind: kind,
            reporterId: currentVaultUserID ?? "local-driver"
        )
        // Keep same-stop history so age-weighted fusion can corroborate / contradict.
        let peers = crowdReports.filter {
            $0.note == stop.id && ($0.type == .laybyFull || $0.type == .laybySpaces)
        }
        let uniqueReporters = Set(peers.map(\.reporterId)).count
        crowdReports.append(report)
        await hazardNavigationCoordinator.persistCrowdReport(
            report,
            scoreInputs: CrowdConfidenceInputs(
                uniqueVehiclesNearby: max(1, uniqueReporters),
                ageSeconds: 0,
                reporterReputation: 0.85,
                corroborationCount: max(0, peers.count - 1)
            )
        )
        upcomingTruckPois = PoiConfidenceAdjuster.adjust(pois: upcomingTruckPois, reports: crowdReports)
    }

    /// Fits after the MapLibre layer has ingested the new polyline (avoids empty-cache race).
    private func scheduleFitMapToRoute() {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: 120_000_000)
            #if os(macOS)
            fitMapToRoute(padding: .macOSRouteFit)
            #else
            fitMapToRoute()
            #endif
            // Second pass once the style/source is fully settled.
            try? await Task.sleep(nanoseconds: 250_000_000)
            #if os(macOS)
            fitMapToRoute(padding: .macOSRouteFit)
            #else
            fitMapToRoute()
            #endif
        }
    }

    private func navigationCoordinatorDisplayLengths(
        _ canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry
    ) -> [Double] {
        let displayCount = canonical.displayCoordinates.count
        let simCount = canonical.simulationCoordinates.count
        guard displayCount >= 2, simCount >= 2, displayCount != simCount else {
            return canonical.cumulativeLengths
        }
        var result: [Double] = [0]
        for index in 1..<displayCount {
            let fraction = Double(index) / Double(displayCount - 1)
            result.append(fraction * canonical.totalLengthMeters)
        }
        return result
    }

    public func clearRouteGeometry() {
        routeCoordinates = []
        routeCumulativeLengths = []
        routeGeometry = nil
        routeEncodedPolyline = nil
        simulationEngine.stop()
        navigationCoordinator.clearRoute()
        routePlanningCoordinator.cancelPendingWork()
        activeLaneGuidance = nil
        activeLaneManeuver = nil
        activeLaneDistanceMeters = nil
        laybyLoadTask?.cancel()
        truckPoiLoadTask?.cancel()
        hazardNavigationCoordinator.resetRouteHazardState(state: hazardState)
        routeSimulationCoordinator.cancelPhysicsWork()
        tripBriefShareText = nil
        laybyAdvisory = nil
        upcomingLaybys = []
        isLoadingLaybys = false
        upcomingTruckPois = []
        isLoadingTruckPois = false
        restrictionAnnouncements = []
        activeRestrictionAnnouncement = nil
        trafficRerouteAvailable = false
        isEvaluatingTrafficReroute = false
        pendingTrafficAlternate = nil
        lastExternalRouteRequest = nil
        Task {
            await laybyAdvisor.reset()
        }
    }

    private func status(for resolved: ResolvedEndpoint?, text: String) -> EndpointResolutionStatus {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }
        if let resolved, resolved.displayLabel == trimmed {
            return .resolved
        }
        if resolved != nil, resolved?.displayLabel != trimmed {
            return .needsSelection
        }
        if trimmed.count >= 2 { return .needsSelection }
        return .typing
    }

    func invalidateResolutionIfTextChanged(for waypointID: UUID, newText: String) {
        guard let index = routeWaypoints.firstIndex(where: { $0.id == waypointID }) else { return }
        let trimmed = newText.trimmingCharacters(in: .whitespaces)
        if routeWaypoints[index].resolved?.displayLabel != trimmed {
            routeWaypoints[index].resolved = nil
        }
    }

    /// Fits the map viewport to the current route polyline.
    public func fitMapToRoute(padding: MapEdgePadding = .defaultRouteFit) {
        guard !routeCoordinates.isEmpty else { return }
        if mapBridge?.fitRouteBoundsHandler != nil {
            mapBridge?.fitRouteToBounds(padding: padding)
        } else if let region = RoutePolyline.mapRegion(for: routeCoordinates) {
            mapRegion = region
        }
    }

    private struct GeocodeSearchOutcome {
        let suggestions: [GeocodeSuggestion]
        let feedback: String?
    }

    private func performGeocodeSearch(query: String) async -> GeocodeSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let apiKey = orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let near = mapViewportCenter
        let emptyFeedback = "No places found — try a fuller name or city."

        #if os(macOS) || os(iOS)
        if useAppleSearchFallback && apiKey.isEmpty {
            let appleResults = await appleGeocodeSearch.search(
                query: trimmed,
                near: near,
                limit: 8,
                regionSpanMeters: AppleGeocodeSearch.worldwideRegionSpanMeters
            )
            if appleResults.isEmpty {
                return GeocodeSearchOutcome(suggestions: [], feedback: emptyFeedback)
            }
            return GeocodeSearchOutcome(suggestions: appleResults, feedback: nil)
        }
        #endif

        if apiKey.isEmpty {
            let cached = await geocoder.cachedHits(matching: trimmed)
            if !cached.isEmpty {
                return GeocodeSearchOutcome(suggestions: cached, feedback: "Offline geocode cache")
            }
            #if os(iOS)
            // iOS: try Apple MapKit even when HeiGIT key is missing.
            let appleResults = await appleGeocodeSearch.search(
                query: trimmed,
                near: near,
                limit: 8,
                regionSpanMeters: AppleGeocodeSearch.worldwideRegionSpanMeters
            )
            if !appleResults.isEmpty {
                return GeocodeSearchOutcome(suggestions: appleResults, feedback: nil)
            }
            #endif
            return GeocodeSearchOutcome(
                suggestions: [],
                feedback: "Add HeiGIT API key in Settings, or enable Apple search fallback"
            )
        }

        var results: [GeocodeSuggestion] = []
        let preferGlobal = OpenRouteServiceGeocoder.querySuggestsOutsideUnitedKingdom(trimmed)
        let language = preferredSearchLanguage

        try? await Task.sleep(for: .milliseconds(350))
        if !Task.isCancelled {
            if let global = try? await geocoder.searchGlobal(
                query: trimmed,
                near: near,
                apiKey: apiKey,
                language: language
            ) {
                results.append(contentsOf: global)
            }
            if !preferGlobal,
               let biased = try? await geocoder.searchBiased(
                query: trimmed,
                near: near,
                apiKey: apiKey,
                language: language
               ) {
                results.append(contentsOf: biased)
            }
        }

        var seen = Set<String>()
        var deduped = results.filter { seen.insert($0.id).inserted }

        if searchEnglishFallback, deduped.count < 3, language.lowercased() != "en" {
            if let englishGlobal = try? await geocoder.searchGlobal(
                query: trimmed,
                near: near,
                apiKey: apiKey,
                language: "en"
            ) {
                for suggestion in englishGlobal where seen.insert(suggestion.id).inserted {
                    deduped.append(suggestion)
                }
            }
            if !preferGlobal,
               let englishBiased = try? await geocoder.searchBiased(
                query: trimmed,
                near: near,
                apiKey: apiKey,
                language: "en"
               ) {
                for suggestion in englishBiased where seen.insert(suggestion.id).inserted {
                    deduped.append(suggestion)
                }
            }
        }

        #if os(macOS) || os(iOS)
        // Empty Pelias (incl. overseas) → Apple worldwide; also when Settings toggle is on.
        if useAppleSearchFallback || deduped.isEmpty {
            let appleResults = await appleGeocodeSearch.search(
                query: trimmed,
                near: near,
                limit: 8,
                regionSpanMeters: AppleGeocodeSearch.worldwideRegionSpanMeters
            )
            for suggestion in appleResults where seen.insert(suggestion.id).inserted {
                deduped.append(suggestion)
            }
        }
        #endif

        if deduped.isEmpty {
            return GeocodeSearchOutcome(
                suggestions: [],
                feedback: emptyFeedback
            )
        }

        return GeocodeSearchOutcome(suggestions: Array(deduped.prefix(8)), feedback: nil)
    }

    private func makeExternalPlanner() throws -> RoutePlanner {
        let client = try OpenRouteServiceRoutingClient(apiKey: orsAPIKey)
        return RoutePlanner(externalClient: client)
    }

    private func updateCloudRoutingBanner() {
        let serviceLabel: String
        if preferOfflineRouting, offlineRoutingEnabled {
            serviceLabel = "Offline tiled routing (preferred)"
        } else if hasORSAPIKey {
            serviceLabel = "Routing via HeiGIT OpenRouteService (`api.heigit.org/openrouteservice/v2`)"
        } else if offlineRoutingEnabled {
            serviceLabel = "Offline tiled routing"
        } else {
            serviceLabel = "Routing via HeiGIT OpenRouteService (`api.heigit.org/openrouteservice/v2`)"
        }

        if orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !offlineRoutingEnabled {
            cloudRoutingBanner = "\(serviceLabel) — add your API key in Settings."
            return
        }

        if isCalculating {
            cloudRoutingBanner = serviceLabel
            return
        }

        if hasCompletedCloudRoute, result != nil {
            cloudRoutingBanner = serviceLabel
            return
        }

        cloudRoutingBanner = serviceLabel
    }

    /// Applies a user-chosen simulation camera zoom and keeps tracking from overriding it.
    public func setSimulationCameraZoom(_ zoom: Double) {
        routeSimulationCoordinator.setSimulationCameraZoom(zoom)
    }

    /// Updates the lane-keep popup from the upcoming turn instruction.
    public func refreshActiveLaneGuidance() {
        guard let result else {
            activeLaneGuidance = nil
            activeLaneManeuver = nil
            activeLaneDistanceMeters = nil
            return
        }
        let arcLength = navigationMetrics.snapshot?.arcLengthMeters
            ?? simulationEngine.currentArcLengthMeters
        let catalog = navigationCoordinator.session.maneuverAnchorCatalog
        let remainingToManeuver: Double
        if let distance = catalog?.distanceToNextManeuver(from: arcLength) {
            remainingToManeuver = distance
        } else if let index = navigationMetrics.snapshot?.currentManeuverIndex,
                  result.turnInstructions.indices.contains(index) {
            remainingToManeuver = max(0, result.turnInstructions[index].distance)
        } else {
            remainingToManeuver = .greatestFiniteMagnitude
        }

        let upcoming: TurnInstruction?
        if let nextID = catalog?.nextAnchor(after: arcLength)?.id {
            upcoming = result.turnInstructions.first { $0.id == nextID }
        } else if let index = navigationMetrics.snapshot?.currentManeuverIndex,
                  result.turnInstructions.indices.contains(index) {
            upcoming = result.turnInstructions[index]
        } else {
            upcoming = nil
        }

        guard let instruction = upcoming, remainingToManeuver <= 250 else {
            activeLaneGuidance = nil
            activeLaneManeuver = nil
            activeLaneDistanceMeters = nil
            return
        }

        activeLaneManeuver = instruction.maneuver
        activeLaneDistanceMeters = remainingToManeuver

        if let lane = instruction.laneGuidance {
            activeLaneGuidance = lane
            return
        }

        if remainingToManeuver <= 180 {
            activeLaneGuidance = TurnLanesParser.heuristic(for: instruction.maneuver)
            return
        }

        activeLaneGuidance = nil
        activeLaneManeuver = nil
        activeLaneDistanceMeters = nil
    }

    /// Submits a local crowd hazard report and optionally schedules a “still there?” prompt.
    public func submitCrowdHazardReport(type: HazardEventType, note: String?) {
        guard let coordinate = simulationEngine.currentCoordinate
            ?? routeCoordinates.first.map({
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }) else {
            return
        }
        let report = CrowdReport(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            type: type,
            reporterId: currentVaultUserID ?? "local-driver"
        )
        crowdReports.append(report)
        Task {
            await hazardNavigationCoordinator.persistCrowdReport(report)
        }
        upcomingTruckPois = PoiConfidenceAdjuster.adjust(pois: upcomingTruckPois, reports: crowdReports)
        if let hazard = hazardNavigationCoordinator.recordCrowdReport(report, state: hazardState) {
            appendHazardOverlay(hazard)
        }
        presentHazardReportSheet = false
        let promptID = report.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard result != nil else { return }
            pendingStillTherePrompt = CrowdReportStillTherePrompt(
                id: promptID,
                reportType: type,
                message: note?.isEmpty == false
                    ? "Is “\(note!)” still there?"
                    : "Is the \(type.rawValue) report still there?"
            )
        }
    }

    /// Confirms or dismisses a still-there crowd prompt.
    public func resolveStillTherePrompt(stillPresent: Bool) {
        defer { pendingStillTherePrompt = nil }
        guard stillPresent, let prompt = pendingStillTherePrompt,
              let coordinate = simulationEngine.currentCoordinate else { return }
        let hazard = HazardEvent(
            id: "crowd-confirm-\(prompt.id)",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: 90,
            type: prompt.reportType,
            severity: .high,
            validFrom: Date(),
            validTo: Date().addingTimeInterval(45 * 60),
            source: "crowd:confirm"
        )
        appendHazardOverlay(hazard)
    }

    private var currentVaultUserID: String? {
        apiKeyVault?.userID
    }

    private func appendHazardOverlay(_ hazard: HazardEvent) {
        hazardNavigationCoordinator.appendHazardOverlay(
            hazard,
            state: hazardState,
            context: hazardNavigationContext()
        )
    }

    private func hazardNavigationContext() -> HazardNavigationContext? {
        let coordinates = routeCoordinates.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard coordinates.count >= 2, result != nil else { return nil }
        return HazardNavigationContext(
            routeCoordinates: coordinates,
            currentRouteArcLengthMeters: currentRouteArcLengthMeters,
            hasActiveRoute: true,
            tomTomAPIKey: tomTomAPIKey,
            hasTomTomAPIKey: hasTomTomAPIKey,
            vehicleClass: resolvedVehicleClass,
            displayMeasurementSystem: displayMeasurementSystem,
            hazardVoiceAlertsEnabled: hazardVoiceAlertsEnabled
        )
    }
}

extension RouteViewModel: FleetDispatchHost {
    public func fleetSnapshotBuildInputs() -> FleetSnapshotBuildInputs? {
        guard let tripId = activeDispatchTripId else { return nil }
        return FleetSnapshotBuildInputs(
            tripId: tripId,
            orderedStopIds: routeWaypoints.map(\.id),
            physicsETASeconds: journeyPhysicsETASeconds ?? physicsPredictedDurationSeconds,
            predictiveReport: simulationEngine.telemetryReport,
            predictedLayby: laybyAdvisory,
            rehearsed: simulationEngine.telemetryReport != nil
        )
    }
}

extension RouteViewModel: RoutePlanningHost {}

extension RouteViewModel: RouteSimulationHost {
    public func rankBreakNowLayby(
        currentArcLengthMeters: Double,
        speedMps: Double,
        predictionInput: LaybyPredictionInput
    ) async -> LaybyAdvisory? {
        await laybyAdvisor.updatePredictionContext(predictionInput)
        return await laybyAdvisor.breakNowAdvisory(
            currentArcLengthMeters: currentArcLengthMeters,
            speedMps: speedMps,
            predictionInput: predictionInput
        )
    }

    public func publishRehearsedDispatchSnapshot() async {
        await publishDispatchSnapshot(status: .rehearsed)
    }

#if os(iOS)
    public func speakKineticAdvisory(_ advisory: KineticAdvisory) {
        voiceGuidanceCoordinator.speakKineticAdvisory(advisory)
    }

    public func speakLaybyAdvisory(_ prompt: String, laybyId: String) {
        voiceGuidanceCoordinator.speakLaybyAdvisory(prompt, laybyId: laybyId)
    }
#endif
}

extension RouteViewModel: HosAdvisoryHost {}

private final class LaneGuidanceNavigationAdapter: NavigationSessionDelegate {
    var onProgress: (() -> Void)?

    func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        onProgress?()
    }
}

private final class NavigationProgressRefreshAdapter: NavigationSessionDelegate {
    var onThrottledProgress: (() -> Void)?
    private var lastRefresh: Date?
    private let minimumIntervalSeconds: TimeInterval = 10

    func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        let now = Date()
        if let lastRefresh, now.timeIntervalSince(lastRefresh) < minimumIntervalSeconds {
            return
        }
        self.lastRefresh = now
        onThrottledProgress?()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
