import Contracts
import Foundation

/// In-memory fleet dispatch store for MVP / local demos (org → vehicles → trips).
public actor InMemoryFleetStore: FleetDispatchPort {
    private var orgById: [UUID: FleetOrg] = [:]
    private var vehicleById: [UUID: FleetVehicle] = [:]
    private var tripById: [UUID: FleetTrip] = [:]
    private var activeTripByVehicle: [UUID: UUID] = [:]

    public init() {}

    public func createOrg(name: String) async throws -> FleetOrg {
        let org = FleetOrg(name: name)
        orgById[org.id] = org
        return org
    }

    public func registerVehicle(_ vehicle: FleetVehicle) async throws -> FleetVehicle {
        vehicleById[vehicle.id] = vehicle
        return vehicle
    }

    public func pushTrip(_ trip: FleetTrip) async throws -> FleetTrip {
        var pushed = trip
        pushed.status = .dispatched
        pushed.updatedAt = Date()
        tripById[pushed.id] = pushed
        activeTripByVehicle[pushed.vehicleId] = pushed.id
        return pushed
    }

    public func activeTrip(forVehicleId vehicleId: UUID) async throws -> FleetTrip? {
        guard let tripId = activeTripByVehicle[vehicleId] else { return nil }
        return tripById[tripId]
    }

    public func applySnapshot(_ snapshot: FleetTripSnapshot) async throws -> FleetTrip {
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
        trip.updatedAt = snapshot.updatedAt
        tripById[trip.id] = trip
        return trip
    }

    public func orgs() async throws -> [FleetOrg] {
        Array(orgById.values).sorted { $0.name < $1.name }
    }

    public func vehicles(forOrgId orgId: UUID) async throws -> [FleetVehicle] {
        vehicleById.values.filter { $0.orgId == orgId }.sorted { $0.label < $1.label }
    }

    public func createAndPushTrip(
        orgId: UUID,
        vehicleId: UUID,
        stops: [FleetTripStop],
        companyBreaks: [CompanyBreakAllocation] = [],
        vehicleProfile: VehicleProfile? = nil
    ) async throws -> FleetTrip {
        let trip = try FleetTripBuilder.makeTrip(
            orgId: orgId,
            vehicleId: vehicleId,
            stops: stops,
            companyBreaks: companyBreaks,
            vehicleProfile: vehicleProfile
        )
        return try await pushTrip(trip)
    }

    public func trip(id: UUID) async throws -> FleetTrip? {
        tripById[id]
    }

    /// Seeds a demo org, vehicle, and 3-stop UK job for acceptance testing.
    public func seedDemoThreeStopJob() async throws -> (org: FleetOrg, vehicle: FleetVehicle, trip: FleetTrip) {
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
}
