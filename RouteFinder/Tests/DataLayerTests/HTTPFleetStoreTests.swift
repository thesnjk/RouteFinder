import Contracts
import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

@Test func httpFleetStoreSyncsTripsOverLANServer() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPFleetStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18080
    let store = DiskFleetStore(storageDirectory: storageDir)
    let router = FleetRouterBuilder.buildRouter(store: store)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )

    let serverTask = Task {
        try await app.runService()
    }
    defer {
        serverTask.cancel()
    }

    try await Task.sleep(nanoseconds: 300_000_000)

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    let client = HTTPFleetStore(baseURL: baseURL)

    let health = try await client.checkHealth()
    #expect(health.ok)

    let org = try await client.createOrg(name: "HTTP Test Ltd")
    let vehicle = try await client.registerVehicle(
        FleetVehicle(orgId: org.id, label: "Artic HTTP", registrationPlate: "HT01 TST")
    )

    let vehicles = try await client.vehicles(forOrgId: org.id)
    #expect(vehicles.count == 1)
    #expect(vehicles.first?.id == vehicle.id)

    let trip = try await client.createAndPushTrip(
        orgId: org.id,
        vehicleId: vehicle.id,
        stops: [
            FleetTripStop(sequence: 0, label: "Origin", latitude: 51.95, longitude: 1.35, role: .origin),
            FleetTripStop(sequence: 1, label: "Destination", latitude: 53.48, longitude: -2.24, role: .destination),
        ],
        companyBreaks: [CompanyBreakAllocation.demoAfternoonBreak()]
    )
    #expect(trip.status == .dispatched)

    let active = try await client.activeTrip(forVehicleId: vehicle.id)
    #expect(active?.id == trip.id)

    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "http-layby",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "Test Layby"
        ),
        distanceRemainingMeters: 5_000,
        estimatedArrivalSeconds: 1_800,
        confidence: 0.75,
        occupancyPrior: .low,
        isAdvisory: true
    )
    let snapshot = FleetTripSnapshot(
        tripId: trip.id,
        status: .rehearsed,
        orderedStopIds: trip.stops.map(\.id),
        physicsETASeconds: 8_400,
        predictedLayby: layby
    )
    let updated = try await client.applySnapshot(snapshot)
    #expect(updated.predictedLayby?.stop.id == "http-layby")

    let secondClient = HTTPFleetStore(baseURL: baseURL)
    let fetched = try await secondClient.activeTrip(forVehicleId: vehicle.id)
    #expect(fetched?.status == .rehearsed)
    #expect(fetched?.predictedLayby?.stop.label == "Test Layby")
}

@Test func fleetStoreFactoryUsesDiskStoreByDefault() {
    FleetWorkspaceSettings.saveUseRemoteFleetServer(false)
    let store = FleetStoreFactory.makeStore()
    #expect(store is DiskFleetStore)
}

@Test func fleetStoreFactoryUsesHTTPStoreWhenRemoteEnabled() throws {
    FleetWorkspaceSettings.saveUseRemoteFleetServer(true)
    FleetWorkspaceSettings.saveFleetServerURL(URL(string: "http://127.0.0.1:8080")!)
    let store = FleetStoreFactory.makeStore()
    #expect(store is HTTPFleetStore)
    FleetWorkspaceSettings.saveUseRemoteFleetServer(false)
    FleetWorkspaceSettings.saveFleetServerURL(nil)
}
