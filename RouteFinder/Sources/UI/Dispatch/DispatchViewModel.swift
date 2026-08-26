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
    public var draft = DispatchTripDraft.ukDemoTemplate()
    public private(set) var activeTrip: FleetTrip?
    public var statusMessage: String?
    public var toastMessage: String?
    public var isPushing = false
    public var isLoading = false
    public var isPreviewLoading = false
    public private(set) var previewCoordinates: [CLLocationCoordinate2D] = []

    public var searchSuggestions: [UUID: [GeocodeSuggestion]] = [:]
    public var searchFeedback: [UUID: String] = [:]

    private var store: any FleetDispatchPort
    nonisolated(unsafe) private var fleetStoreConfigurationObserver: NSObjectProtocol?
    private let geocoder = OpenRouteServiceGeocoder()
    #if os(macOS) || os(iOS)
    private let appleGeocodeSearch = AppleGeocodeSearch()
    #endif
    private var pollTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var searchTasks: [UUID: Task<Void, Never>] = [:]

    /// Creates a dispatch view model backed by the shared disk store.
    public init(store: (any FleetDispatchPort)? = nil) {
        self.store = store ?? FleetStoreFactory.makeStore()
        fleetStoreConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .fleetStoreConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.reloadFleetStore()
            }
        }
    }

    deinit {
        if let fleetStoreConfigurationObserver {
            NotificationCenter.default.removeObserver(fleetStoreConfigurationObserver)
        }
    }

    /// Replaces the active fleet store from current workspace settings.
    public func reloadFleetStore() async {
        store = FleetStoreFactory.makeStore()
        await refreshCatalog()
        await refreshActiveTrip()
        if FleetWorkspaceSettings.useRemoteFleetServer(),
           FleetWorkspaceSettings.loadFleetServerURL() != nil {
            statusMessage = "Fleet store switched to remote."
        } else {
            statusMessage = "Fleet store switched to local disk."
        }
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
        } catch {
            statusMessage = error.localizedDescription
        }
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
                vehicleProfile: profile
            )
            activeTrip = trip
            FleetWorkspaceSettings.saveFleetVehicleId(vehicleId)
            let vehicleLabel = vehicles.first(where: { $0.id == vehicleId })?.label ?? "vehicle"
            showToast("Dispatched to \(vehicleLabel)")
            startPolling()
            await refreshRoutePreview()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// Loads the active trip for the selected vehicle once.
    public func refreshActiveTrip() async {
        guard let vehicleId = selectedVehicleId else {
            activeTrip = nil
            return
        }
        activeTrip = try? await store.activeTrip(forVehicleId: vehicleId)
        await refreshRoutePreview()
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

        let apiKey = VehicleProfileStore.loadORSAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !apiKey.isEmpty, let request = buildPreviewRequest(from: fallback) else {
            previewCoordinates = fallback
            return
        }

        isPreviewLoading = true
        defer { isPreviewLoading = false }

        do {
            let client = try OpenRouteServiceRoutingClient(apiKey: apiKey)
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
        let apiKey = VehicleProfileStore.loadORSAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if apiKey.isEmpty {
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
            searchFeedback[stopId] = "Add HeiGIT API key in Settings for address search."
            return
        }

        var results: [GeocodeSuggestion] = []
        if let global = try? await geocoder.searchGlobal(query: query, near: near, apiKey: apiKey) {
            results.append(contentsOf: global)
        }
        if let biased = try? await geocoder.searchBiased(query: query, near: near, apiKey: apiKey) {
            results.append(contentsOf: biased)
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
