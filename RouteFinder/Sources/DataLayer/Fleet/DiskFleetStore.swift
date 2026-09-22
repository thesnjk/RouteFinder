import Contracts
import Foundation

/// Disk-backed fleet dispatch store (org → vehicles → trips) with JSON persistence.
public actor DiskFleetStore: FleetDispatchPort {
    private var orgById: [UUID: FleetOrg] = [:]
    private var vehicleById: [UUID: FleetVehicle] = [:]
    private var tripById: [UUID: FleetTrip] = [:]
    private var activeTripByVehicle: [UUID: UUID] = [:]

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var didLoad = false

    private struct Snapshot: Codable, Sendable {
        var orgs: [FleetOrg]
        var vehicles: [FleetVehicle]
        var trips: [FleetTrip]
        var activeTripByVehicle: [String: String]
    }

    /// Creates a store under Application Support (or a custom directory for tests).
    public init(storageDirectory: URL? = nil) {
        if let storageDirectory {
            directory = storageDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            directory = support.appendingPathComponent("RouteFinder/fleet", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func createOrg(name: String) async throws -> FleetOrg {
        try await loadIfNeeded()
        let org = FleetOrg(name: name)
        orgById[org.id] = org
        try persist()
        return org
    }

    public func registerVehicle(_ vehicle: FleetVehicle) async throws -> FleetVehicle {
        try await loadIfNeeded()
        vehicleById[vehicle.id] = vehicle
        try persist()
        return vehicle
    }

    public func pushTrip(_ trip: FleetTrip) async throws -> FleetTrip {
        try await loadIfNeeded()
        var pushed = trip
        pushed.status = .dispatched
        pushed.updatedAt = Date()
        tripById[pushed.id] = pushed
        activeTripByVehicle[pushed.vehicleId] = pushed.id
        try persist()
        return pushed
    }

    public func activeTrip(forVehicleId vehicleId: UUID) async throws -> FleetTrip? {
        try await loadIfNeeded()
        guard let tripId = activeTripByVehicle[vehicleId] else { return nil }
        return tripById[tripId]
    }

    public func applySnapshot(_ snapshot: FleetTripSnapshot) async throws -> FleetTrip {
        try await loadIfNeeded()
        guard var trip = tripById[snapshot.tripId] else {
            throw FleetStoreError.tripNotFound
        }
        let byId = Dictionary(uniqueKeysWithValues: trip.stops.map { ($0.id, $0) })
        var reordered: [FleetTripStop] = []
        for (index, stopId) in snapshot.orderedStopIds.enumerated() {
            guard var stop = byId[stopId] else { continue }
            stop.sequence = index
            reordered.append(stop)
        }
        if reordered.count == snapshot.orderedStopIds.count {
            trip.stops = reordered
        }
        trip.status = snapshot.status
        trip.physicsETASeconds = snapshot.physicsETASeconds
        trip.predictiveReport = snapshot.predictiveReport
        trip.predictedLayby = snapshot.predictedLayby
        if let summary = snapshot.latestInspectionSummary {
            trip.latestInspectionSummary = summary
        }
        if let pdf = snapshot.inspectionReportPDFBase64 {
            trip.inspectionReportPDFBase64 = pdf
        }
        if let latitude = snapshot.driverLatitude {
            trip.driverLatitude = latitude
        }
        if let longitude = snapshot.driverLongitude {
            trip.driverLongitude = longitude
        }
        if let recordedAt = snapshot.driverLocationRecordedAt {
            trip.driverLocationRecordedAt = recordedAt
        }
        trip.updatedAt = snapshot.updatedAt
        tripById[trip.id] = trip
        try persist()
        return trip
    }

    public func orgs() async throws -> [FleetOrg] {
        try await loadIfNeeded()
        return Array(orgById.values).sorted { $0.name < $1.name }
    }

    public func vehicles(forOrgId orgId: UUID) async throws -> [FleetVehicle] {
        try await loadIfNeeded()
        return vehicleById.values.filter { $0.orgId == orgId }.sorted { $0.label < $1.label }
    }

    public func createAndPushTrip(
        orgId: UUID,
        vehicleId: UUID,
        stops: [FleetTripStop],
        companyBreaks: [CompanyBreakAllocation] = [],
        vehicleProfile: VehicleProfile? = nil,
        jobBrief: FleetJobBrief? = nil
    ) async throws -> FleetTrip {
        let trip = try FleetTripBuilder.makeTrip(
            orgId: orgId,
            vehicleId: vehicleId,
            stops: stops,
            companyBreaks: companyBreaks,
            vehicleProfile: vehicleProfile,
            jobBrief: jobBrief
        )
        return try await pushTrip(trip)
    }

    public func trip(id: UUID) async throws -> FleetTrip? {
        try await loadIfNeeded()
        return tripById[id]
    }

    /// Appends a read-only telematics ping (webhook stub). Caps at 200 entries.
    public func ingestTelematics(_ request: TelematicsIngestRequest) async throws -> TelematicsVehiclePing {
        try await loadIfNeeded()
        let provider: TelematicsProvider
        if let raw = request.provider?.lowercased() {
            if raw.contains("geotab") {
                provider = .geotab
            } else if raw.contains("samsara") {
                provider = .samsara
            } else {
                provider = .unknown
            }
        } else {
            provider = .unknown
        }
        let label = request.vehicleLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ping = TelematicsVehiclePing(
            provider: provider,
            vehicleLabel: (label?.isEmpty == false ? label! : request.vehicleId.uuidString),
            latitude: request.latitude,
            longitude: request.longitude,
            recordedAt: request.recordedAt
        )
        var pings = try loadTelematicsPings()
        pings.append(ping)
        if pings.count > 200 {
            pings = Array(pings.suffix(200))
        }
        try saveTelematicsPings(pings)
        return ping
    }

    /// Latest telematics pings (newest last), for smoke tests / future GET.
    public func latestTelematicsPings(limit: Int = 50) async throws -> [TelematicsVehiclePing] {
        try await loadIfNeeded()
        let pings = try loadTelematicsPings()
        guard limit > 0 else { return [] }
        return Array(pings.suffix(limit))
    }

    /// Seeds a demo org, vehicle, and 3-stop UK job (persisted across restarts).
    public func seedDemoThreeStopJob() async throws -> (org: FleetOrg, vehicle: FleetVehicle, trip: FleetTrip) {
        try await loadIfNeeded()
        let org = try await createOrg(name: "Demo Haulage Ltd")
        let vehicle = try await registerVehicle(
            FleetVehicle(
                orgId: org.id,
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
        let trip = try await pushTrip(
            FleetTrip(
                orgId: org.id,
                vehicleId: vehicle.id,
                status: .dispatched,
                stops: [
                    FleetTripStop(
                        sequence: 0,
                        label: "Felixstowe Port",
                        latitude: 51.9542,
                        longitude: 1.3511,
                        role: .origin
                    ),
                    FleetTripStop(
                        sequence: 1,
                        label: "Midlands Hub",
                        latitude: 52.4862,
                        longitude: -1.8904,
                        role: .via
                    ),
                    FleetTripStop(
                        sequence: 2,
                        label: "Manchester Depot",
                        latitude: 53.4808,
                        longitude: -2.2426,
                        role: .destination
                    ),
                ],
                vehicleProfile: vehicle.profile,
                companyBreaks: [CompanyBreakAllocation.demoAfternoonBreak()]
            )
        )
        return (org, vehicle, trip)
    }

    private var snapshotURL: URL {
        directory.appendingPathComponent("fleet-store.json")
    }

    private var telematicsURL: URL {
        directory.appendingPathComponent("telematics-pings.json")
    }

    private func loadTelematicsPings() throws -> [TelematicsVehiclePing] {
        guard FileManager.default.fileExists(atPath: telematicsURL.path) else { return [] }
        let data = try Data(contentsOf: telematicsURL)
        return try decoder.decode([TelematicsVehiclePing].self, from: data)
    }

    private func saveTelematicsPings(_ pings: [TelematicsVehiclePing]) throws {
        let data = try encoder.encode(pings)
        try data.write(to: telematicsURL, options: .atomic)
    }

    private func loadIfNeeded() async throws {
        guard !didLoad else { return }
        didLoad = true
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        let data = try Data(contentsOf: snapshotURL)
        let snapshot = try decoder.decode(Snapshot.self, from: data)
        orgById = Dictionary(uniqueKeysWithValues: snapshot.orgs.map { ($0.id, $0) })
        vehicleById = Dictionary(uniqueKeysWithValues: snapshot.vehicles.map { ($0.id, $0) })
        tripById = Dictionary(uniqueKeysWithValues: snapshot.trips.map { ($0.id, $0) })
        activeTripByVehicle = [:]
        for (vehicleKey, tripKey) in snapshot.activeTripByVehicle {
            guard let vehicleId = UUID(uuidString: vehicleKey),
                  let tripId = UUID(uuidString: tripKey) else { continue }
            activeTripByVehicle[vehicleId] = tripId
        }
    }

    private func persist() throws {
        let snapshot = Snapshot(
            orgs: Array(orgById.values),
            vehicles: Array(vehicleById.values),
            trips: Array(tripById.values),
            activeTripByVehicle: Dictionary(
                uniqueKeysWithValues: activeTripByVehicle.map {
                    ($0.key.uuidString, $0.value.uuidString)
                }
            )
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }
}
