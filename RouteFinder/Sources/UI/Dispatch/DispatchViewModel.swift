import Contracts
import DataLayer
import Foundation

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
    public var isPushing = false
    public var isLoading = false

    private let store: any FleetDispatchPort
    private var pollTask: Task<Void, Never>?

    /// Creates a dispatch view model backed by the shared disk store.
    public init(store: (any FleetDispatchPort)? = nil) {
        self.store = store ?? DiskFleetStore()
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
            statusMessage = "Dispatched trip to \(vehicles.first(where: { $0.id == vehicleId })?.label ?? "vehicle")."
            startPolling()
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
    }
}
