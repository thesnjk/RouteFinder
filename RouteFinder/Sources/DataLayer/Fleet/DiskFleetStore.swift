import Contracts
import Foundation

/// Disk-backed fleet dispatch store (org → vehicles → trips) with JSON persistence.
public actor DiskFleetStore: FleetDispatchPort {
    private var orgs: [UUID: FleetOrg] = [:]
    private var vehicles: [UUID: FleetVehicle] = [:]
    private var trips: [UUID: FleetTrip] = [:]
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
        orgs[org.id] = org
        try persist()
        return org
    }

    public func registerVehicle(_ vehicle: FleetVehicle) async throws -> FleetVehicle {
        try await loadIfNeeded()
        vehicles[vehicle.id] = vehicle
        try persist()
        return vehicle
    }

    public func pushTrip(_ trip: FleetTrip) async throws -> FleetTrip {
        try await loadIfNeeded()
        var pushed = trip
        pushed.status = .dispatched
        pushed.updatedAt = Date()
        trips[pushed.id] = pushed
        activeTripByVehicle[pushed.vehicleId] = pushed.id
        try persist()
        return pushed
    }

    public func activeTrip(forVehicleId vehicleId: UUID) async throws -> FleetTrip? {
        try await loadIfNeeded()
        guard let tripId = activeTripByVehicle[vehicleId] else { return nil }
        return trips[tripId]
    }

    public func applySnapshot(_ snapshot: FleetTripSnapshot) async throws -> FleetTrip {
        try await loadIfNeeded()
        guard var trip = trips[snapshot.tripId] else {
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
        trip.updatedAt = snapshot.updatedAt
        trips[trip.id] = trip
        try persist()
        return trip
    }

    public func trip(id: UUID) async throws -> FleetTrip? {
        try await loadIfNeeded()
        return trips[id]
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
                vehicleProfile: vehicle.profile
            )
        )
        return (org, vehicle, trip)
    }

    private var snapshotURL: URL {
        directory.appendingPathComponent("fleet-store.json")
    }

    private func loadIfNeeded() async throws {
        guard !didLoad else { return }
        didLoad = true
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else { return }
        let data = try Data(contentsOf: snapshotURL)
        let snapshot = try decoder.decode(Snapshot.self, from: data)
        orgs = Dictionary(uniqueKeysWithValues: snapshot.orgs.map { ($0.id, $0) })
        vehicles = Dictionary(uniqueKeysWithValues: snapshot.vehicles.map { ($0.id, $0) })
        trips = Dictionary(uniqueKeysWithValues: snapshot.trips.map { ($0.id, $0) })
        activeTripByVehicle = [:]
        for (vehicleKey, tripKey) in snapshot.activeTripByVehicle {
            guard let vehicleId = UUID(uuidString: vehicleKey),
                  let tripId = UUID(uuidString: tripKey) else { continue }
            activeTripByVehicle[vehicleId] = tripId
        }
    }

    private func persist() throws {
        let snapshot = Snapshot(
            orgs: Array(orgs.values),
            vehicles: Array(vehicles.values),
            trips: Array(trips.values),
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
