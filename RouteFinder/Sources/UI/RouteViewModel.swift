import Contracts
import CoreLocation
import CostModel
import DataLayer
import MapLibreUI
import NavigationCore
import RouteController
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
    /// Draft text for Settings SecureField (never pre-filled from Keychain).
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
    public var emissionClass: EmissionClass?
    public var activeProfileName: String?
    public var vehicleRegistration: String = ""
    public var vehicleTypeLabel: String = ""
    public var vehicleAxleCount: String = ""
    public var vehicleEnginePowerHP: String = ""
    public var registrationLookupError: String?
    public var registrationLookupInProgress = false
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

    public var isCalculating = false
    public var result: SearchResult?
    public var errorMessage: String?
    public var routeFailure: RouteFailurePresentation?
    public var cloudRoutingBanner: String?
    public var routeCoordinates: [CLLocationCoordinate2D] = []
    public var routeCumulativeLengths: [Double] = []
    public var routeGeometry: RouteGeometry?
    public var routeEncodedPolyline: String?
    public var routeEncodedPolylinePrecision: Int = 6
    public var hazardOverlayJSON = "{\"type\":\"FeatureCollection\",\"features\":[]}"

    #if os(iOS)
    public var isFollowModeEnabled = false
    public var isNavigationActive = false
    #endif

    public var interactionMode: MapInteractionMode = .navigate
    public var activePinTarget: MapPinTarget = .none
    public var pendingDisambiguation: GeocodeDisambiguationRequest?

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
    private let appleGeocodeSearch = AppleGeocodeSearch()
    private let locationResolver = LocationResolver()
    private var vehicleRegistryClient = VehicleRegistryClient()
    private var recalculateTask: Task<Void, Never>?
    private var searchTasks: [UUID: Task<Void, Never>] = [:]
    private var hasCompletedCloudRoute = false

    #if os(iOS)
    private let voiceGuidanceCoordinator = VoiceGuidanceCoordinator()
    #endif

    private var apiKeyVault: APIKeyVault?

    public convenience init() {
        self.init(vault: nil)
    }

    public init(vault: APIKeyVault?) {
        apiKeyVault = vault
        let savedTomTomKey = (try? vault?.load(.tomTom)) ?? VehicleProfileStore.loadTomTomAPIKey()
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
        let ors = (try? vault?.load(.ors)) ?? VehicleProfileStore.loadORSAPIKey()
        let dvla = (try? vault?.load(.dvla)) ?? VehicleProfileStore.loadDVLAAPIKey()
        let regCheck = (try? vault?.load(.regCheckUsername)) ?? VehicleProfileStore.loadRegCheckUsername()
        let openWeather = (try? vault?.load(.openWeather)) ?? VehicleProfileStore.loadOpenWeatherAPIKey()
        if let ors, !ors.isEmpty {
            orsAPIKey = ors
            hasORSAPIKey = true
        }
        if let dvla, !dvla.isEmpty {
            dvlaAPIKey = dvla
            hasDVLAAPIKey = true
        }
        if let regCheck, !regCheck.isEmpty {
            regCheckUsername = regCheck
            hasRegCheckUsername = true
        }
        if let savedTomTomKey, !savedTomTomKey.isEmpty {
            tomTomAPIKey = savedTomTomKey
            hasTomTomAPIKey = true
        }
        if let openWeather, !openWeather.isEmpty {
            openWeatherAPIKey = openWeather
            hasOpenWeatherAPIKey = true
        }
        #if os(macOS)
        if orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            useAppleSearchFallback = true
        }
        #endif
        wireNavigationPipeline()
        updateCloudRoutingBanner()
    }

    /// Attaches or refreshes the Keychain vault after login.
    public func bindVault(_ vault: APIKeyVault?) {
        apiKeyVault = vault
        guard let vault else { return }
        try? vault.migrateFromUserDefaultsIfNeeded()
        applyLoadedSecrets(
            ors: loadSecret(.ors),
            dvla: loadSecret(.dvla),
            regCheck: loadSecret(.regCheckUsername),
            tomTom: loadSecret(.tomTom),
            openWeather: loadSecret(.openWeather)
        )
        updateCloudRoutingBanner()
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
        } else {
            hasDVLAAPIKey = false
        }
        dvlaAPIKeyDraft = ""
        if let regCheck, !regCheck.isEmpty {
            regCheckUsername = regCheck
            hasRegCheckUsername = true
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
            try? apiKeyVault.save(value, for: kind)
        } else {
            switch kind {
            case .ors: VehicleProfileStore.saveORSAPIKey(value)
            case .openWeather: VehicleProfileStore.saveOpenWeatherAPIKey(value)
            case .dvla: VehicleProfileStore.saveDVLAAPIKey(value)
            case .tomTom: VehicleProfileStore.saveTomTomAPIKey(value)
            case .regCheckUsername: VehicleProfileStore.saveRegCheckUsername(value)
            }
        }
    }

    private func wireNavigationPipeline() {
        navigationCoordinator.configureSimulationPoseSource { [weak self] in
            guard let self, let coordinate = self.simulationEngine.currentCoordinate else { return nil }
            return (
                coordinate: coordinate,
                bearing: self.simulationEngine.currentBearing,
                speedKmh: self.simulationEngine.currentSpeedKmh,
                arcLengthMeters: self.simulationEngine.currentArcLengthMeters
            )
        }
        simulationEngine.onDisplayFrameTick = { [weak self] in
            self?.navigationCoordinator.emitSimulationPose()
        }
        simulationEngine.onSimulationStarted = { [weak self] in
            Task { @MainActor in
                try? await self?.navigationCoordinator.startSimulationNavigation()
            }
        }
        simulationEngine.onSimulationStopped = { [weak self] in
            self?.navigationCoordinator.stopNavigation()
        }
        NavigationSessionRegistry.shared = navigationCoordinator.session
        #if os(iOS)
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
        emissionClass = profile.emissionClass
        activeProfileName = profile.savedProfileName
        refreshMapVehicleFootprint()
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

        let client = vehicleRegistryClient
        do {
            let spec = try await client.lookupSpecification(
                registration: sanitized,
                manualClassOverride: vehicleClassOverride
            )
            resolvedSpecificationProfile = spec
            syncMapBridgeSpecificationProfile()
            let profile = spec.toRegistryProfile()
            applyRegistryProfile(profile)
            vehicleRegistration = RegistrationNormalizer.formatForDisplay(sanitized)
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
        } catch {
            registrationLookupError = error.localizedDescription
            navigationCoordinator.reportInvalidVehicleProfile(error.localizedDescription)
            vehicleTypeLabel = ""
            registrationSource = nil
            resolvedSpecificationProfile = nil
            syncMapBridgeSpecificationProfile()
        }
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
        simulationEngine.simulationSpeedMultiplier = multiplier.rawValue
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

    /// Persists the DVLA Vehicle Enquiry Service API key to the Keychain vault.
    public func persistDVLAAPIKey() {
        let value = dvlaAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        dvlaAPIKey = value
        hasDVLAAPIKey = true
        dvlaAPIKeyDraft = ""
        persistSecret(value, kind: .dvla)
    }

    /// Persists the RegCheck account username to the Keychain vault.
    public func persistRegCheckUsername() {
        let value = regCheckUsernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        regCheckUsername = value
        hasRegCheckUsername = true
        regCheckUsernameDraft = ""
        persistSecret(value, kind: .regCheckUsername)
        vehicleRegistryClient = vehicleRegistryClient.rebuildProviders()
    }

    /// Persists the TomTom Traffic Flow API key to the Keychain vault.
    public func persistTomTomAPIKey() {
        let value = tomTomAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        tomTomAPIKey = value
        hasTomTomAPIKey = true
        tomTomAPIKeyDraft = ""
        persistSecret(value, kind: .tomTom)
    }

    /// Persists the OpenWeather API key to the Keychain vault.
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
        simulationEngine.updateEnvironmentalContext(environmentalContext)
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
        } catch {
            optimizationError = error.localizedDescription
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

    /// Persists the HeiGIT API key to the Keychain vault.
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
        recalculateTask?.cancel()
        recalculateTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            guard originWaypoint.isResolved, destinationWaypoint.isResolved else { return }
            await calculateRoute()
        }
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
            try await calculateExternalRoute(preferences: preferences)
            hasCompletedCloudRoute = true
            routeFailure = nil
            updateCloudRoutingBanner()
        } catch {
            presentRouteError(error, preferences: preferences)
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
            preferences: preferences
        )

        let externalPlanner = try makeExternalPlanner()
        let (searchResult, response) = try await externalPlanner.calculateExternalRoute(request: request)
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
            staticTotalTimeSeconds: searchResult.metrics.totalTime
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
            minimumTurnRadiusMeters: physics.turningRadiusMeters
        )
        scheduleFitMapToRoute()
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

    private func clearRouteGeometry() {
        routeCoordinates = []
        routeCumulativeLengths = []
        routeGeometry = nil
        routeEncodedPolyline = nil
        simulationEngine.stop()
        navigationCoordinator.clearRoute()
    }

    private func presentRouteError(_ error: Error, preferences: RoutingPreferences) {
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? DecodingDiagnostics.userMessage(for: error)
        routeFailure = RouteFailureMapper.map(
            error,
            vehicle: preferences.vehicle,
            isHGVMode: preferences.isHGVMode
        )
        result = nil
        clearRouteGeometry()
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

        #if os(macOS)
        if useAppleSearchFallback && apiKey.isEmpty {
            let appleResults = await appleGeocodeSearch.search(query: trimmed, near: near, limit: 8)
            if appleResults.isEmpty {
                return GeocodeSearchOutcome(
                    suggestions: [],
                    feedback: "No matches — try a more specific place name"
                )
            }
            return GeocodeSearchOutcome(suggestions: appleResults, feedback: nil)
        }
        #endif

        if apiKey.isEmpty {
            return GeocodeSearchOutcome(
                suggestions: [],
                feedback: "Add HeiGIT API key in Settings, or enable Apple search fallback"
            )
        }

        var results: [GeocodeSuggestion] = []

        try? await Task.sleep(for: .milliseconds(350))
        if !Task.isCancelled {
            if let biased = try? await geocoder.searchBiased(query: trimmed, near: near, apiKey: apiKey) {
                results.append(contentsOf: biased)
            }
        }

        if !Task.isCancelled {
            if let global = try? await geocoder.searchGlobal(query: trimmed, near: near, apiKey: apiKey) {
                results.append(contentsOf: global)
            }
        }

        var seen = Set<String>()
        let deduped = results.filter { seen.insert($0.id).inserted }

        if deduped.isEmpty {
            #if os(macOS)
            if useAppleSearchFallback {
                let appleResults = await appleGeocodeSearch.search(query: trimmed, near: near, limit: 8)
                if !appleResults.isEmpty {
                    return GeocodeSearchOutcome(suggestions: appleResults, feedback: nil)
                }
            }
            #endif
            return GeocodeSearchOutcome(
                suggestions: [],
                feedback: "No matches for “\(trimmed)”"
            )
        }

        return GeocodeSearchOutcome(suggestions: Array(deduped.prefix(8)), feedback: nil)
    }

    private func makeExternalPlanner() throws -> RoutePlanner {
        let client = try OpenRouteServiceRoutingClient(apiKey: orsAPIKey)
        return RoutePlanner(externalClient: client)
    }

    private func updateCloudRoutingBanner() {
        let serviceLabel = "Routing via HeiGIT OpenRouteService (`api.heigit.org/openrouteservice/v2`)"

        if orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
}
