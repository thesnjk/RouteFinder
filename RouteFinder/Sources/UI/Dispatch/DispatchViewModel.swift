import Contracts
import CoreLocation
import DataLayer
import Foundation
import RouteController

#if os(macOS) || os(iOS)
import MapKit
#endif

/// View model for the native fleet dispatch console (local disk store).
@MainActor
@Observable
public final class DispatchViewModel {
    public private(set) var orgs: [FleetOrg] = []
    public private(set) var vehicles: [FleetVehicle] = []
    public var selectedOrgId: UUID?
    public var selectedVehicleId: UUID?
    /// Filter query for vehicle picker + roster poll (label / plate).
    public var vehicleFilterQuery: String = ""
    /// All / Hide offline / Defects only — applied after text filter using roster GPS/defects.
    public var vehiclePickerMode: DispatchRosterPickerMode = .all
    public var draft = DispatchTripDraft.ukDemoTemplate()
    public private(set) var activeTrip: FleetTrip?
    /// Fleet roster rows (capped) from last roster poll (text-filtered; mode applied in `displayedRosterRows`).
    public private(set) var rosterRows: [DispatchRosterRow] = []
    /// Yard GPS pins derived from roster (all cabs with published location).
    public private(set) var fleetPins: [DispatchRosterPin] = []
    public var statusMessage: String?
    public var toastMessage: String?
    public var isPushing = false
    public var isLoading = false
    public var isPreviewLoading = false
    public private(set) var previewCoordinates: [CLLocationCoordinate2D] = []
    /// Fleet server health: `true` connected, `false` offline/auth-failed, `nil` not checked / local disk.
    public private(set) var fleetServerHealthOk: Bool?
    public private(set) var fleetServerVersion: String?
    /// Pill copy: Connected / Auth failed · … / Offline / nil when local or unchecked.
    public private(set) var fleetServerHealthDetail: String?
    public private(set) var fleetServerModeLabel: String = "Local disk"
    /// Draft shared fleet API key for inline desk paste (Auth failed recovery).
    public var fleetAPIKeyDraft: String = ""
    /// True while persisting the desk fleet API key and re-probing health.
    public private(set) var isSavingFleetAPIKey = false
    /// Last telematics CSV import (read-only stub) for status panel.
    public private(set) var telematicsImportBatch: TelematicsImportBatch?

    public var searchSuggestions: [UUID: [GeocodeSuggestion]] = [:]
    public var searchFeedback: [UUID: String] = [:]

    private var store: any FleetDispatchPort
    private let telematicsImportStore = TelematicsImportStore()
    @ObservationIgnored private let fleetStoreConfigurationObserver = FleetStoreConfigurationObserver()
    #if os(macOS) || os(iOS)
    private let appleGeocodeSearch = AppleGeocodeSearch()
    #endif
    private var pollTask: Task<Void, Never>?
    private var rosterPollTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var searchTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastAnnouncedInspectionSummary: TripBriefInspectionSummary?

    /// Creates a dispatch view model backed by the shared disk store.
    public init(store: (any FleetDispatchPort)? = nil) {
        self.store = store ?? FleetStoreFactory.makeStore()
        fleetStoreConfigurationObserver.token = NotificationCenter.default.addObserver(
            forName: .fleetStoreConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.reloadFleetStore()
            }
        }
    }

    /// Replaces the active fleet store from current workspace settings.
    public func reloadFleetStore() async {
        store = FleetStoreFactory.makeStore()
        await refreshCatalog()
        await refreshActiveTrip()
        await refreshFleetServerHealth()
        if FleetWorkspaceSettings.useRemoteFleetServer(),
           FleetWorkspaceSettings.loadFleetServerURL() != nil {
            statusMessage = "Fleet store switched to remote."
        } else {
            statusMessage = "Fleet store switched to local disk."
        }
    }

    /// Reloads the last telematics CSV import for the status panel.
    public func reloadTelematicsImport() async {
        telematicsImportBatch = await telematicsImportStore.load()
    }

    /// Loads orgs and vehicles from disk.
    public func refreshCatalog() async {
        isLoading = true
        defer { isLoading = false }
        do {
            orgs = try await store.orgs()
            if selectedOrgId == nil {
                selectedOrgId = orgs.first?.id
            }
            if let orgId = selectedOrgId {
                vehicles = try await store.vehicles(forOrgId: orgId)
                if selectedVehicleId == nil {
                    selectedVehicleId = vehicles.first?.id
                }
            }
            await refreshRoutePreview()
            await refreshRoster()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// Vehicles matching `vehicleFilterQuery` only (used for roster poll scope).
    public var textFilteredVehicles: [FleetVehicle] {
        DispatchFleetRoster.filterVehicles(vehicles, query: vehicleFilterQuery)
    }

    /// Vehicles for the trip-form picker (text filter + roster mode).
    public var filteredVehicles: [FleetVehicle] {
        let textFiltered = textFilteredVehicles
        let statusByID = Dictionary(
            uniqueKeysWithValues: rosterRows.map {
                ($0.vehicleId, (gpsAgeSeconds: $0.gpsAgeSeconds, hasDefects: $0.hasDefects))
            }
        )
        let allowed = Set(
            DispatchRosterPickerFilter.filterOrderedIDs(
                textFiltered.map(\.id),
                mode: vehiclePickerMode,
                statusByID: statusByID
            )
        )
        return textFiltered.filter { allowed.contains($0.id) }
    }

    /// Roster panel rows after applying the same picker mode.
    public var displayedRosterRows: [DispatchRosterRow] {
        rosterRows.filter { row in
            DispatchRosterPickerFilter.includes(
                mode: vehiclePickerMode,
                gpsAgeSeconds: row.gpsAgeSeconds,
                hasDefects: row.hasDefects,
                hasRosterData: true
            )
        }
    }

    /// True when push has a vehicle, ≥2 resolved stops, remote fleet, and Connected health.
    public var canPushTrip: Bool {
        let resolved = draft.stops.filter(hasValidCoordinates).count >= 2
        return DispatchPushGate.canPush(
            hasVehicle: selectedVehicleId != nil,
            hasResolvedStops: resolved,
            isRemoteFleet: fleetServerModeLabel != "Local disk",
            healthOk: fleetServerHealthOk == true
        )
    }

    /// Draft is otherwise ready but Local disk / Offline / Auth failed blocks push.
    public var isPushBlockedByFleetHealth: Bool {
        let resolved = draft.stops.filter(hasValidCoordinates).count >= 2
        return DispatchPushGate.isBlockedByFleetHealth(
            hasVehicle: selectedVehicleId != nil,
            hasResolvedStops: resolved,
            isRemoteFleet: fleetServerModeLabel != "Local disk",
            healthOk: fleetServerHealthOk == true
        )
    }

    /// Show inline fleet API key paste when remote and not Connected.
    public var needsFleetAPIKeyPaste: Bool {
        DispatchFleetKeyPasteGate.needsPaste(
            isRemoteFleet: fleetServerModeLabel != "Local disk",
            healthOk: fleetServerHealthOk
        )
    }

    /// Selects a roster vehicle and refreshes its active trip immediately.
    public func selectRosterVehicle(_ vehicleId: UUID) async {
        guard vehicles.contains(where: { $0.id == vehicleId }) else { return }
        selectedVehicleId = vehicleId
        FleetWorkspaceSettings.saveFleetVehicleId(vehicleId)
        await refreshActiveTrip()
    }

    /// Loads active trips for capped text-filtered vehicles into `rosterRows` / `fleetPins`.
    public func refreshRoster() async {
        let capped = Array(textFilteredVehicles.prefix(DispatchFleetRoster.vehicleCap))
        guard !capped.isEmpty else {
            rosterRows = []
            fleetPins = []
            return
        }
        var tripByVehicleId: [UUID: FleetTrip?] = [:]
        for vehicle in capped {
            tripByVehicleId[vehicle.id] = try? await store.activeTrip(forVehicleId: vehicle.id)
        }
        let rows = DispatchFleetRoster.buildRows(
            vehicles: capped,
            tripByVehicleId: tripByVehicleId,
            now: Date()
        )
        rosterRows = rows
        fleetPins = DispatchFleetRoster.driverPins(from: rows)
    }

    /// Ensures a demo org and vehicle exist for local MVP demos.
    public func bootstrapDemoFleet() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let existing = try await store.orgs().first(where: { $0.name == "Demo Haulage Ltd" }) {
                selectedOrgId = existing.id
            } else {
                let org = try await store.createOrg(name: "Demo Haulage Ltd")
                selectedOrgId = org.id
            }
            guard let orgId = selectedOrgId else { return }
            vehicles = try await store.vehicles(forOrgId: orgId)
            if vehicles.isEmpty {
                let vehicle = try await store.registerVehicle(
                    FleetVehicle(
                        orgId: orgId,
                        label: "Artic 1",
                        registrationPlate: "AB12 CDE",
                        profile: VehicleProfile(
                            height: 4.0,
                            weight: 44,
                            width: 2.55,
                            length: 16.5,
                            axleWeight: 11.5
                        )
                    )
                )
                vehicles = [vehicle]
            }
            selectedVehicleId = vehicles.first?.id
            FleetWorkspaceSettings.saveFleetVehicleId(vehicles.first!.id)
            orgs = try await store.orgs()
            statusMessage = "Demo fleet ready — select a vehicle and push a trip."
            await refreshRoutePreview()
            await refreshRoster()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// Pushes the current draft as a dispatched trip to the selected vehicle.
    public func pushDraftTrip() async {
        guard let orgId = selectedOrgId, let vehicleId = selectedVehicleId else {
            statusMessage = "Select an org and vehicle first."
            return
        }
        guard canPushTrip else {
            let message = isPushBlockedByFleetHealth
                ? "Connect to the fleet server — health pill must show Connected before push."
                : "Select a vehicle and resolve origin and destination first."
            statusMessage = message
            showToast(message)
            return
        }
        isPushing = true
        defer { isPushing = false }
        do {
            let stops = try draft.fleetStops()
            let profile = vehicles.first(where: { $0.id == vehicleId })?.profile
            let trip = try await store.createAndPushTrip(
                orgId: orgId,
                vehicleId: vehicleId,
                stops: stops,
                companyBreaks: draft.companyBreaks(),
                vehicleProfile: profile,
                jobBrief: draft.jobBrief()
            )
            activeTrip = trip
            FleetWorkspaceSettings.saveFleetVehicleId(vehicleId)
            let vehicleLabel = vehicles.first(where: { $0.id == vehicleId })?.label ?? "vehicle"
            showToast("Dispatched to \(vehicleLabel)")
            startPolling()
            startRosterPolling()
            await refreshRoutePreview()
            await refreshRoster()
        } catch {
            let message = error.localizedDescription
            statusMessage = message
            showToast(message)
        }
    }

    /// Loads the active trip for the selected vehicle once.
    public func refreshActiveTrip() async {
        guard let vehicleId = selectedVehicleId else {
            activeTrip = nil
            return
        }
        let previousTrip = activeTrip
        activeTrip = try? await store.activeTrip(forVehicleId: vehicleId)
        announceInspectionDefectsIfNeeded(
            previousSummary: previousTrip?.latestInspectionSummary,
            newSummary: activeTrip?.latestInspectionSummary
        )
        await refreshRoutePreview()
    }

    private func announceInspectionDefectsIfNeeded(
        previousSummary: TripBriefInspectionSummary?,
        newSummary: TripBriefInspectionSummary?
    ) {
        guard DispatchInspectionAnnouncer.shouldAnnounce(
            previousSummary: previousSummary,
            newSummary: newSummary,
            lastAnnounced: lastAnnouncedInspectionSummary
        ), let summary = newSummary else {
            return
        }
        showToast(DispatchInspectionAnnouncer.toastMessage(for: summary))
        lastAnnouncedInspectionSummary = summary
    }

    /// Starts polling active trip status for dispatch visibility.
    public func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshActiveTrip()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    /// Stops background polling.
    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Starts fleet-wide roster polling (~8s, web parity).
    public func startRosterPolling() {
        rosterPollTask?.cancel()
        rosterPollTask = Task { [weak self] in
            await self?.refreshRoster()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await self?.refreshRoster()
            }
        }
    }

    /// Stops fleet roster polling.
    public func stopRosterPolling() {
        rosterPollTask?.cancel()
        rosterPollTask = nil
    }

    /// Starts health polling for remote HTTP fleet stores (every 10s).
    public func startHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = Task { [weak self] in
            await self?.refreshFleetServerHealth()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await self?.refreshFleetServerHealth()
            }
        }
    }

    /// Stops fleet server health polling.
    public func stopHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = nil
    }

    /// Refreshes fleet server reachability for the health pill.
    ///
    /// Green only when `/health` and a protected auth probe both succeed (avoids false-green
    /// on public health when `--api-key` is required). Distinguishes Auth failed vs Offline.
    public func refreshFleetServerHealth() async {
        guard FleetWorkspaceSettings.useRemoteFleetServer(),
              let url = FleetWorkspaceSettings.loadFleetServerURL() else {
            fleetServerModeLabel = "Local disk"
            fleetServerHealthOk = nil
            fleetServerVersion = nil
            fleetServerHealthDetail = nil
            return
        }
        fleetServerModeLabel = "Remote"
        let apiKey = try? FleetServerCredentials.loadAPIKey()
        prefillFleetAPIKeyDraftIfNeeded(loadedKey: apiKey)
        let client = HTTPFleetStore(baseURL: url, apiKey: apiKey)
        do {
            let health = try await client.checkHealth()
            guard health.ok else {
                fleetServerHealthOk = false
                fleetServerVersion = nil
                fleetServerHealthDetail = FleetServerHealthLabel.status(
                    healthOk: false,
                    authSucceeded: false
                )
                return
            }
            do {
                try await client.verifyAuthenticatedAccess()
                fleetServerHealthOk = true
                fleetServerVersion = health.version
                fleetServerHealthDetail = FleetServerHealthLabel.status(
                    healthOk: true,
                    authSucceeded: true,
                    version: health.version
                )
            } catch {
                fleetServerHealthOk = false
                fleetServerVersion = nil
                if FleetServerHealthLabel.isAuthFailure(error) {
                    fleetServerHealthDetail = FleetServerHealthLabel.status(
                        healthOk: true,
                        authSucceeded: false,
                        authErrorMessage: error.localizedDescription
                    )
                } else {
                    fleetServerHealthDetail = FleetServerHealthLabel.status(
                        healthOk: false,
                        authSucceeded: false
                    )
                }
            }
        } catch {
            fleetServerHealthOk = false
            fleetServerVersion = nil
            if FleetServerHealthLabel.isAuthFailure(error) {
                fleetServerHealthDetail = FleetServerHealthLabel.status(
                    healthOk: true,
                    authSucceeded: false,
                    authErrorMessage: error.localizedDescription
                )
            } else {
                fleetServerHealthDetail = FleetServerHealthLabel.status(
                    healthOk: false,
                    authSucceeded: false
                )
            }
        }
    }

    /// Persists the inline desk fleet API key and re-probes Connected health.
    public func saveFleetAPIKeyAndReprobe() async {
        isSavingFleetAPIKey = true
        defer { isSavingFleetAPIKey = false }
        do {
            try FleetServerCredentials.saveAPIKey(fleetAPIKeyDraft)
            // Keychain save posts `.fleetStoreConfigurationDidChange` → reloadFleetStore.
            await refreshFleetServerHealth()
            if fleetServerHealthOk == true {
                showToast("Fleet API key saved — Connected")
            } else if let detail = fleetServerHealthDetail {
                showToast(detail)
            }
        } catch {
            let message = error.localizedDescription
            statusMessage = message
            showToast(message)
        }
    }

    private func prefillFleetAPIKeyDraftIfNeeded(loadedKey: String?) {
        guard fleetAPIKeyDraft.isEmpty,
              let loadedKey,
              !loadedKey.isEmpty else {
            return
        }
        fleetAPIKeyDraft = loadedKey
    }

    /// Updates vehicle list when org selection changes.
    public func orgSelectionChanged() async {
        guard let orgId = selectedOrgId else {
            vehicles = []
            selectedVehicleId = nil
            return
        }
        vehicles = (try? await store.vehicles(forOrgId: orgId)) ?? []
        if !vehicles.contains(where: { $0.id == selectedVehicleId }) {
            selectedVehicleId = vehicles.first?.id
        }
        await refreshActiveTrip()
        await refreshRoster()
        await refreshRoutePreview()
    }

    /// Label for the selected vehicle (dispatch brief header).
    public var selectedVehicleLabel: String? {
        guard let vehicleId = selectedVehicleId,
              let vehicle = vehicles.first(where: { $0.id == vehicleId }) else {
            return nil
        }
        if let plate = vehicle.registrationPlate, !plate.isEmpty {
            return "\(vehicle.label) (\(plate))"
        }
        return vehicle.label
    }

    /// Returns geocode suggestions for a stop row.
    public func suggestions(for stopId: UUID) -> [GeocodeSuggestion] {
        searchSuggestions[stopId] ?? []
    }

    /// Returns search feedback for a stop row.
    public func feedback(for stopId: UUID) -> String? {
        searchFeedback[stopId]
    }

    /// Resolution status for dispatch stop search fields.
    func resolutionStatus(for stopId: UUID) -> EndpointResolutionStatus {
        guard let stop = draft.stops.first(where: { $0.id == stopId }) else {
            return .empty
        }
        if hasValidCoordinates(stop) {
            return .resolved
        }
        if let feedback = searchFeedback[stopId], !feedback.isEmpty {
            return .error(feedback)
        }
        let trimmed = stop.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .empty
        }
        if !(searchSuggestions[stopId]?.isEmpty ?? true) {
            return .needsSelection
        }
        return .typing
    }

    /// Debounced geocode typeahead for a stop label field.
    public func updateSearchSuggestions(for stopId: UUID, query: String) {
        searchTasks[stopId]?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchSuggestions[stopId] = []
            searchFeedback[stopId] = nil
            return
        }
        searchTasks[stopId] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.performSearch(for: stopId, query: trimmed)
        }
    }

    /// Applies a geocode suggestion to a stop and refreshes the route preview.
    public func applySuggestion(_ suggestion: GeocodeSuggestion, for stopId: UUID) async {
        guard let index = draft.stops.firstIndex(where: { $0.id == stopId }) else { return }
        draft.stops[index].label = suggestion.subtitle
        draft.stops[index].latitude = String(suggestion.coordinate.latitude)
        draft.stops[index].longitude = String(suggestion.coordinate.longitude)
        searchSuggestions[stopId] = []
        searchFeedback[stopId] = nil
        await refreshRoutePreview()
    }

    /// Refreshes the dispatch map preview (ORS HGV route or straight-line fallback).
    public func refreshRoutePreview() async {
        previewTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            await self?.loadRoutePreview()
        }
        previewTask = task
        await task.value
    }

    private func loadRoutePreview() async {
        let fallback = straightLinePreview()
        guard fallback.count >= 2 else {
            previewCoordinates = fallback
            return
        }

        let localKey = VehicleProfileStore.loadORSAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let useRemote = FleetWorkspaceSettings.useRemoteFleetServer()
        let fleetURL = FleetWorkspaceSettings.loadFleetServerURL()
        let canRoute = !localKey.isEmpty || FleetORSRoutingFactory.usesFleetProxy(useRemoteFleetServer: useRemote, fleetServerURL: fleetURL)
        guard canRoute, let request = buildPreviewRequest(from: fallback) else {
            previewCoordinates = fallback
            return
        }

        isPreviewLoading = true
        defer { isPreviewLoading = false }

        do {
            let fleetKey = try? FleetServerCredentials.loadAPIKey()
            let client = try FleetORSRoutingFactory.makeRoutingClient(
                localORSAPIKey: localKey.isEmpty ? "unused" : localKey,
                useRemoteFleetServer: useRemote,
                fleetServerURL: fleetURL,
                fleetAPIKey: fleetKey
            )
            let response = try await client.route(request: request)
            guard !Task.isCancelled else { return }
            let coords = response.coordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            previewCoordinates = coords.count >= 2 ? coords : fallback
        } catch {
            previewCoordinates = fallback
        }
    }

    private func buildPreviewRequest(from coordinates: [CLLocationCoordinate2D]) -> ExternalRouteRequest? {
        guard coordinates.count >= 2 else { return nil }
        let routing = coordinates.map {
            RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        let vehicle = selectedVehicleProfile()
        return ExternalRouteRequest(
            origin: routing[0],
            destination: routing[routing.count - 1],
            waypoints: Array(routing.dropFirst().dropLast()),
            vehicle: vehicle,
            preferences: RoutingPreferences(
                isHGVMode: true,
                vehicle: vehicle,
                requestSegmentSpeedLimits: false
            )
        )
    }

    private func selectedVehicleProfile() -> VehicleProfile {
        if let vehicleId = selectedVehicleId,
           let profile = vehicles.first(where: { $0.id == vehicleId })?.profile {
            return profile
        }
        return VehicleProfile(
            height: 4.0,
            weight: 44,
            width: 2.55,
            length: 16.5,
            axleWeight: 11.5
        )
    }

    private func straightLinePreview() -> [CLLocationCoordinate2D] {
        let coords: [Coordinate]
        if let trip = activeTrip, !trip.stops.isEmpty {
            coords = DispatchRoutePreviewBuilder.straightLineCoordinates(from: trip.stops)
        } else {
            coords = DispatchRoutePreviewBuilder.straightLineCoordinates(from: draft)
        }
        return coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func performSearch(for stopId: UUID, query: String) async {
        let near = MapDefaults.ukCenter
        let localKey = VehicleProfileStore.loadORSAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let useRemote = FleetWorkspaceSettings.useRemoteFleetServer()
        let fleetURL = FleetWorkspaceSettings.loadFleetServerURL()
        let usesFleetProxy = FleetORSRoutingFactory.usesFleetProxy(
            useRemoteFleetServer: useRemote,
            fleetServerURL: fleetURL
        )
        let canGeocode = !localKey.isEmpty || usesFleetProxy

        if !canGeocode {
            #if os(iOS)
            let appleResults = await appleGeocodeSearch.search(
                query: query,
                near: near,
                limit: 8,
                regionSpanMeters: AppleGeocodeSearch.worldwideRegionSpanMeters
            )
            if !appleResults.isEmpty {
                searchSuggestions[stopId] = appleResults
                searchFeedback[stopId] = nil
                return
            }
            #endif
            searchSuggestions[stopId] = []
            searchFeedback[stopId] = "Add HeiGIT API key in Settings or enable fleet ORS proxy for address search."
            return
        }

        let fleetKey = try? FleetServerCredentials.loadAPIKey()
        let geocoder = FleetORSRoutingFactory.makeGeocoder(
            localORSAPIKey: localKey,
            useRemoteFleetServer: useRemote,
            fleetServerURL: fleetURL,
            fleetAPIKey: fleetKey
        )
        let apiKey = usesFleetProxy
            ? FleetORSRoutingFactory.fleetProxyAuthKey(fleetAPIKey: fleetKey)
            : localKey

        var results: [GeocodeSuggestion] = []
        do {
            let global = try await geocoder.searchGlobal(query: query, near: near, apiKey: apiKey)
            results.append(contentsOf: global)
            let biased = try await geocoder.searchBiased(query: query, near: near, apiKey: apiKey)
            results.append(contentsOf: biased)
        } catch let error as OpenRouteServiceGeocoderError {
            if case .rateLimited = error {
                searchSuggestions[stopId] = []
                searchFeedback[stopId] =
                    "Fleet ORS daily geocode cap reached — ask the operator or wait until tomorrow."
                return
            }
            searchSuggestions[stopId] = []
            searchFeedback[stopId] = error.localizedDescription
            return
        } catch {
            searchSuggestions[stopId] = []
            searchFeedback[stopId] = error.localizedDescription
            return
        }

        var seen = Set<String>()
        var deduped = results.filter { seen.insert($0.id).inserted }

        #if os(macOS) || os(iOS)
        if deduped.isEmpty {
            let appleResults = await appleGeocodeSearch.search(
                query: query,
                near: near,
                limit: 8,
                regionSpanMeters: AppleGeocodeSearch.worldwideRegionSpanMeters
            )
            for suggestion in appleResults where seen.insert(suggestion.id).inserted {
                deduped.append(suggestion)
            }
        }
        #endif

        searchSuggestions[stopId] = Array(deduped.prefix(8))
        searchFeedback[stopId] = deduped.isEmpty ? "No results — try a postcode or city." : nil
    }

    private func hasValidCoordinates(_ stop: DispatchStopDraft) -> Bool {
        Double(stop.latitude.trimmingCharacters(in: .whitespaces)) != nil
            && Double(stop.longitude.trimmingCharacters(in: .whitespaces)) != nil
            && !stop.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
