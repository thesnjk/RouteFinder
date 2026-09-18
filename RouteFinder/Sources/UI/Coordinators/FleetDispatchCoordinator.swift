import Contracts
import DataLayer
import Foundation

/// Inputs required to publish a fleet trip snapshot to dispatch.
public struct FleetSnapshotBuildInputs: Sendable {
    /// Active dispatch trip identifier.
    public let tripId: UUID
    /// Ordered stop ids along the driver route.
    public let orderedStopIds: [UUID]
    /// Physics-predicted ETA in seconds.
    public let physicsETASeconds: Double?
    /// Latest predictive telemetry report, if rehearsed.
    public let predictiveReport: PredictiveTelemetryReport?
    /// Nearest layby advisory, if any.
    public let predictedLayby: LaybyAdvisory?
    /// Whether simulation rehearsal has produced telemetry.
    public let rehearsed: Bool
    /// Driver latitude (WGS84), when known.
    public let driverLatitude: Double?
    /// Driver longitude (WGS84), when known.
    public let driverLongitude: Double?
    /// When the driver location was recorded.
    public let driverLocationRecordedAt: Date?

    /// Creates snapshot build inputs.
    public init(
        tripId: UUID,
        orderedStopIds: [UUID],
        physicsETASeconds: Double?,
        predictiveReport: PredictiveTelemetryReport?,
        predictedLayby: LaybyAdvisory?,
        rehearsed: Bool,
        driverLatitude: Double? = nil,
        driverLongitude: Double? = nil,
        driverLocationRecordedAt: Date? = nil
    ) {
        self.tripId = tripId
        self.orderedStopIds = orderedStopIds
        self.physicsETASeconds = physicsETASeconds
        self.predictiveReport = predictiveReport
        self.predictedLayby = predictedLayby
        self.rehearsed = rehearsed
        self.driverLatitude = driverLatitude
        self.driverLongitude = driverLongitude
        self.driverLocationRecordedAt = driverLocationRecordedAt
    }
}

/// Host surface for fleet dispatch orchestration owned by ``RouteViewModel``.
@MainActor
public protocol FleetDispatchHost: AnyObject {
    var activeDispatchTripId: UUID? { get set }
    var fleetVehicleId: UUID? { get set }
    var fleetVehicleIdText: String { get set }
    var fleetServerURLText: String { get set }
    var fleetServerAPIKeyText: String { get set }
    var useRemoteFleetServer: Bool { get set }
    var fleetServerConnectionStatus: String? { get set }
    var discoveredFleetServers: [DiscoveredFleetServer] { get set }
    var isDiscoveringFleetServers: Bool { get set }
    var fleetDiscoveryStatus: String? { get set }
    var fleetDispatchToast: String? { get set }
    var lastPublishedFleetSnapshot: FleetTripSnapshot? { get set }
    func applyDispatchedTrip(_ trip: FleetTrip) async
    func fleetSnapshotBuildInputs() -> FleetSnapshotBuildInputs?
}

/// Coordinates fleet polling, SSE dispatch, and snapshot publishing.
@MainActor
public final class FleetDispatchCoordinator {
    private weak var host: FleetDispatchHost?
    private var fleetStore: any FleetDispatchPort
    private var fleetDispatchToastDismissTask: Task<Void, Never>?
    private var gpsPublishTask: Task<Void, Never>?
    private var lastPublishedDriverLatitude: Double?
    private var lastPublishedDriverLongitude: Double?

    /// Creates a fleet dispatch coordinator bound to the given host.
    public init(host: FleetDispatchHost, fleetStore: any FleetDispatchPort = FleetStoreFactory.makeStore()) {
        self.host = host
        self.fleetStore = fleetStore
    }

    /// Restores fleet workspace settings from disk.
    public func restoreWorkspaceSettings() {
        guard let host else { return }
        if let savedFleetVehicleId = FleetWorkspaceSettings.loadFleetVehicleId() {
            host.fleetVehicleId = savedFleetVehicleId
            host.fleetVehicleIdText = savedFleetVehicleId.uuidString
        }
        host.useRemoteFleetServer = FleetWorkspaceSettings.useRemoteFleetServer()
        if let serverURL = FleetWorkspaceSettings.loadFleetServerURL() {
            host.fleetServerURLText = serverURL.absoluteString
        }
        host.fleetServerAPIKeyText = (try? FleetServerCredentials.loadAPIKey()) ?? ""
    }

    /// Replaces the active fleet store from current workspace settings.
    public func reloadFleetStore() {
        fleetStore = FleetStoreFactory.makeStore()
        guard let host else { return }
        if FleetWorkspaceSettings.useRemoteFleetServer(),
           FleetWorkspaceSettings.loadFleetServerURL() != nil {
            host.fleetServerConnectionStatus = "Fleet store switched to remote."
        } else {
            host.fleetServerConnectionStatus = "Fleet store switched to local disk."
        }
    }

    /// Polls disk store for a newly pushed trip and applies it on the driver device.
    public func pollAndApplyFleetDispatch() async {
        saveFleetVehicleIdFromSettings()
        guard let host, let vehicleId = host.fleetVehicleId else { return }
        guard let trip = try? await fleetStore.activeTrip(forVehicleId: vehicleId) else { return }
        guard trip.id != host.activeDispatchTripId else { return }
        await host.applyDispatchedTrip(trip)
    }

    /// Subscribes to fleet SSE events with fallback polling until the task is cancelled.
    public func startFleetDispatchListener() async {
        var backoffSeconds: UInt64 = 1
        while !Task.isCancelled {
            guard let host,
                  FleetWorkspaceSettings.useRemoteFleetServer(),
                  let baseURL = FleetWorkspaceSettings.loadFleetServerURL(),
                  let vehicleId = host.fleetVehicleId else {
                await pollAndApplyFleetDispatch()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                continue
            }

            let trimmedKey = host.fleetServerAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = trimmedKey.isEmpty ? (try? FleetServerCredentials.loadAPIKey()) : trimmedKey
            let stream = FleetSSEClient.events(baseURL: baseURL, apiKey: apiKey, vehicleId: vehicleId)

            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await event in stream {
                        guard event.kind == .tripPushed else { continue }
                        await self?.handleRemoteTripPushed()
                    }
                }
                group.addTask { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 30_000_000_000)
                        await self?.pollAndApplyFleetDispatch()
                    }
                }
                await group.next()
                group.cancelAll()
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
            backoffSeconds = min(backoffSeconds * 2, 30)
        }
    }

    /// Publishes trip status + physics ETA (and GPS when available) for the dispatch console.
    public func publishDispatchSnapshot(
        status: FleetTripStatus? = nil,
        inspectionSummary: TripBriefInspectionSummary? = nil,
        inspectionReportPDFBase64: String? = nil
    ) async {
        guard let host, let inputs = host.fleetSnapshotBuildInputs() else { return }
        let resolvedStatus = status ?? (inputs.rehearsed ? .rehearsed : .active)
        let snapshot = FleetTripSnapshot(
            tripId: inputs.tripId,
            status: resolvedStatus,
            orderedStopIds: inputs.orderedStopIds,
            physicsETASeconds: inputs.physicsETASeconds,
            predictiveReport: inputs.predictiveReport,
            predictedLayby: inputs.predictedLayby,
            latestInspectionSummary: inspectionSummary,
            inspectionReportPDFBase64: inspectionReportPDFBase64,
            driverLatitude: inputs.driverLatitude,
            driverLongitude: inputs.driverLongitude,
            driverLocationRecordedAt: inputs.driverLocationRecordedAt
        )
        if let latitude = inputs.driverLatitude, let longitude = inputs.driverLongitude {
            lastPublishedDriverLatitude = latitude
            lastPublishedDriverLongitude = longitude
        }
        host.lastPublishedFleetSnapshot = snapshot
        _ = try? await fleetStore.applySnapshot(snapshot)
        startPeriodicGPSPublishIfNeeded()
    }

    /// Starts a 20s GPS snapshot loop while an active dispatch trip is present.
    public func startPeriodicGPSPublishIfNeeded() {
        guard gpsPublishTask == nil else { return }
        guard host?.activeDispatchTripId != nil else { return }
        gpsPublishTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.publishGPSSnapshotIfChanged()
            }
        }
    }

    /// Stops the periodic GPS publish loop.
    public func stopPeriodicGPSPublish() {
        gpsPublishTask?.cancel()
        gpsPublishTask = nil
        lastPublishedDriverLatitude = nil
        lastPublishedDriverLongitude = nil
    }

    private func publishGPSSnapshotIfChanged() async {
        guard let host, host.activeDispatchTripId != nil else {
            stopPeriodicGPSPublish()
            return
        }
        guard let inputs = host.fleetSnapshotBuildInputs(),
              let latitude = inputs.driverLatitude,
              let longitude = inputs.driverLongitude else {
            return
        }
        let unchanged =
            lastPublishedDriverLatitude.map { abs($0 - latitude) < 0.00005 } == true
            && lastPublishedDriverLongitude.map { abs($0 - longitude) < 0.00005 } == true
        if unchanged { return }
        await publishDispatchSnapshot()
    }

    /// Publishes inspection handoff to the remote fleet server when configured.
    public func publishInspectionFleetHandoff(
        record: InspectionRecord,
        summary: TripBriefInspectionSummary
    ) async {
        guard let host, host.activeDispatchTripId != nil, host.useRemoteFleetServer else { return }
        let pdfBase64 = InspectionReportPDFRenderer.pdfData(from: record).base64EncodedString()
        await publishDispatchSnapshot(
            inspectionSummary: summary,
            inspectionReportPDFBase64: pdfBase64
        )
    }

    /// Returns the current trip as seen by dispatch (after driver snapshot publish).
    public func fetchDispatchTrip() async -> FleetTrip? {
        guard let tripId = host?.activeDispatchTripId else { return nil }
        return try? await fleetStore.trip(id: tripId)
    }

    /// Persists the fleet vehicle id from Settings text entry.
    public func saveFleetVehicleIdFromSettings() {
        guard let host else { return }
        let trimmed = host.fleetVehicleIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let vehicleId = UUID(uuidString: trimmed) else { return }
        host.fleetVehicleId = vehicleId
        FleetWorkspaceSettings.saveFleetVehicleId(vehicleId)
    }

    /// Persists fleet server settings from Settings text fields.
    public func saveFleetServerURLFromSettings() {
        guard let host else { return }
        let trimmed = host.fleetServerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverURL = trimmed.isEmpty ? nil : URL(string: trimmed)
        if let serverURL {
            host.fleetServerURLText = serverURL.absoluteString
        }
        FleetWorkspaceSettings.saveRemoteFleetConfiguration(
            useRemote: host.useRemoteFleetServer,
            serverURL: serverURL
        )
        try? FleetServerCredentials.saveAPIKey(host.fleetServerAPIKeyText)
    }

    /// Tests connectivity to the configured fleet HTTP server.
    public func testFleetServerConnection() async {
        saveFleetServerURLFromSettings()
        guard let host else { return }
        guard let url = FleetWorkspaceSettings.loadFleetServerURL() else {
            host.fleetServerConnectionStatus = "Enter a fleet server URL first."
            return
        }
        let trimmedKey = host.fleetServerAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = trimmedKey.isEmpty ? nil : trimmedKey
        let client = HTTPFleetStore(baseURL: url, apiKey: apiKey)
        do {
            let health = try await client.checkHealth()
            host.fleetServerConnectionStatus = health.ok
                ? "Connected to fleet server."
                : "Server responded but health check failed."
        } catch {
            host.fleetServerConnectionStatus = error.localizedDescription
        }
    }

    /// Scans the local network for fleet servers advertised via Bonjour.
    public func discoverFleetServersOnLAN() async {
        guard let host else { return }
        host.isDiscoveringFleetServers = true
        host.fleetDiscoveryStatus = "Searching for fleet servers…"
        host.discoveredFleetServers = []
        let servers = await FleetBonjourBrowser.discover()
        host.discoveredFleetServers = servers
        host.isDiscoveringFleetServers = false
        if servers.isEmpty {
            host.fleetDiscoveryStatus = "No fleet servers found. Ensure the dispatch Mac is running RouteFinderFleetServer on the same Wi‑Fi."
        } else {
            host.fleetDiscoveryStatus = "Found \(servers.count) server\(servers.count == 1 ? "" : "s"). Tap one to apply."
        }
    }

    /// Applies a Bonjour-discovered fleet server URL and enables remote sync.
    public func applyDiscoveredFleetServer(_ server: DiscoveredFleetServer) {
        guard let host else { return }
        host.fleetServerURLText = server.baseURL.absoluteString
        host.useRemoteFleetServer = true
        saveFleetServerURLFromSettings()
        reloadFleetStore()
        host.fleetServerConnectionStatus = "Applied \(server.displayName)."
        host.fleetDiscoveryStatus = nil
    }

    /// Seeds a demo 3-stop UK job and applies it to the driver device.
    public func acceptDemoFleetDispatch() async throws {
        guard let host else { return }
        do {
            let seeded = try await DiskFleetStore().seedDemoThreeStopJob()
            host.fleetVehicleId = seeded.vehicle.id
            host.fleetVehicleIdText = seeded.vehicle.id.uuidString
            FleetWorkspaceSettings.saveFleetVehicleId(seeded.vehicle.id)
            await host.applyDispatchedTrip(seeded.trip)
        } catch {
            let fallback = InMemoryFleetStore()
            let seeded = try await fallback.seedDemoThreeStopJob()
            host.fleetVehicleId = seeded.vehicle.id
            host.fleetVehicleIdText = seeded.vehicle.id.uuidString
            FleetWorkspaceSettings.saveFleetVehicleId(seeded.vehicle.id)
            await host.applyDispatchedTrip(seeded.trip)
        }
    }

    /// Shows a transient fleet dispatch toast banner.
    public func showFleetDispatchToast(_ message: String) {
        guard let host else { return }
        host.fleetDispatchToast = message
        fleetDispatchToastDismissTask?.cancel()
        fleetDispatchToastDismissTask = Task { [weak host] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            host?.fleetDispatchToast = nil
        }
    }

    private func handleRemoteTripPushed() async {
        showFleetDispatchToast("New dispatch received — loading route…")
        await pollAndApplyFleetDispatch()
    }
}
