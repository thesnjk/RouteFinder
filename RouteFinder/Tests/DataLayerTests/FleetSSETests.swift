import Contracts
import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

private func startFleetServer(
    port: Int,
    storageDirectory: URL,
    apiKey: String?,
    eventHub: FleetEventHub = FleetEventHub(heartbeatIntervalSeconds: 60)
) -> Task<Void, Never> {
    let store = DiskFleetStore(storageDirectory: storageDirectory)
    let router = FleetRouterBuilder.buildRouter(store: store, apiKey: apiKey, eventHub: eventHub)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    return Task {
        try? await app.runService()
    }
}

@Test func fleetSSEClientReceivesTripPushedEvent() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetSSETests-push-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18090
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: nil)
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    let client = HTTPFleetStore(baseURL: baseURL)
    let org = try await client.createOrg(name: "SSE Test Ltd")
    let vehicle = try await client.registerVehicle(
        FleetVehicle(orgId: org.id, label: "SSE Artic", registrationPlate: "SSE1 TST")
    )

    let stream = FleetSSEClient.events(baseURL: baseURL, apiKey: nil, vehicleId: vehicle.id)
    let receiveTask = Task<FleetDispatchEvent?, Never> {
        for await event in stream {
            return event
        }
        return nil
    }
    defer { receiveTask.cancel() }

    try await Task.sleep(nanoseconds: 200_000_000)

    let trip = try await client.createAndPushTrip(
        orgId: org.id,
        vehicleId: vehicle.id,
        stops: [
            FleetTripStop(sequence: 0, label: "Origin", latitude: 51.95, longitude: 1.35, role: .origin),
            FleetTripStop(sequence: 1, label: "Destination", latitude: 53.48, longitude: -2.24, role: .destination),
        ]
    )

    let event = try await withThrowingTaskGroup(of: FleetDispatchEvent?.self) { group in
        group.addTask { await receiveTask.value }
        group.addTask {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return nil
        }
        guard let first = try await group.next() else { return nil as FleetDispatchEvent? }
        group.cancelAll()
        return first
    }

    #expect(event?.kind == .tripPushed)
    #expect(event?.tripId == trip.id)
    #expect(event?.vehicleId == vehicle.id)
}

@Test func fleetSSEEndpointRejectsMissingAPIKeyWhenConfigured() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetSSETests-auth-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18091
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: "secret-key")
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let vehicleId = UUID()
    guard let url = URL(string: "http://127.0.0.1:\(port)/v1/vehicles/\(vehicleId.uuidString)/events") else {
        Issue.record("Invalid SSE URL.")
        return
    }
    var request = URLRequest(url: url)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

    let (_, response) = try await FleetURLSession.shared.bytes(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode
    #expect(status == 401)
}

@Test func fleetSSEConnectionSurvivesHeartbeatInterval() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetSSETests-heartbeat-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18092
    let eventHub = FleetEventHub(heartbeatIntervalSeconds: 1)
    let serverTask = startFleetServer(
        port: port,
        storageDirectory: storageDir,
        apiKey: nil,
        eventHub: eventHub
    )
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    let client = HTTPFleetStore(baseURL: baseURL)
    let org = try await client.createOrg(name: "Heartbeat Ltd")
    let vehicle = try await client.registerVehicle(
        FleetVehicle(orgId: org.id, label: "HB Artic", registrationPlate: "HB01 TST")
    )

    let stream = FleetSSEClient.events(baseURL: baseURL, apiKey: nil, vehicleId: vehicle.id)
    let receiveTask = Task<FleetDispatchEvent?, Never> {
        for await event in stream {
            return event
        }
        return nil
    }
    defer { receiveTask.cancel() }

    try await Task.sleep(nanoseconds: 2_500_000_000)

    let trip = try await client.createAndPushTrip(
        orgId: org.id,
        vehicleId: vehicle.id,
        stops: [
            FleetTripStop(sequence: 0, label: "A", latitude: 51.95, longitude: 1.35, role: .origin),
            FleetTripStop(sequence: 1, label: "B", latitude: 53.48, longitude: -2.24, role: .destination),
        ]
    )

    let event = try await withThrowingTaskGroup(of: FleetDispatchEvent?.self) { group in
        group.addTask { await receiveTask.value }
        group.addTask {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return nil
        }
        guard let first = try await group.next() else { return nil as FleetDispatchEvent? }
        group.cancelAll()
        return first
    }

    #expect(event?.kind == .tripPushed)
    #expect(event?.tripId == trip.id)
}

@Test func fleetE2EWorkflowPushSnapshotAndSSE() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetE2EWorkflow-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18093
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: nil)
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    let client = HTTPFleetStore(baseURL: baseURL)
    let org = try await client.createOrg(name: "E2E Workflow Ltd")
    let vehicle = try await client.registerVehicle(
        FleetVehicle(orgId: org.id, label: "E2E Artic", registrationPlate: "E2E1 TST")
    )

    let stream = FleetSSEClient.events(baseURL: baseURL, apiKey: nil, vehicleId: vehicle.id)
    let receiveTask = Task<FleetDispatchEvent?, Never> {
        for await event in stream where event.kind == .tripPushed {
            return event
        }
        return nil
    }
    defer { receiveTask.cancel() }

    try await Task.sleep(nanoseconds: 200_000_000)

    let trip = try await client.createAndPushTrip(
        orgId: org.id,
        vehicleId: vehicle.id,
        stops: [
            FleetTripStop(sequence: 0, label: "Felixstowe", latitude: 51.95, longitude: 1.35, role: .origin),
            FleetTripStop(sequence: 1, label: "Manchester", latitude: 53.48, longitude: -2.24, role: .destination),
        ]
    )

    let event = try await withThrowingTaskGroup(of: FleetDispatchEvent?.self) { group in
        group.addTask { await receiveTask.value }
        group.addTask {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return nil
        }
        guard let first = try await group.next() else { return nil as FleetDispatchEvent? }
        group.cancelAll()
        return first
    }

    #expect(event?.kind == .tripPushed)
    #expect(event?.tripId == trip.id)
    #expect(event?.vehicleId == vehicle.id)

    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "e2e-layby",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "E2E Layby A1"
        ),
        distanceRemainingMeters: 4_500,
        estimatedArrivalSeconds: 1_500,
        confidence: 0.8,
        occupancyPrior: .low,
        isAdvisory: true
    )
    let snapshot = FleetTripSnapshot(
        tripId: trip.id,
        status: .rehearsed,
        orderedStopIds: trip.stops.map(\.id),
        physicsETASeconds: 7_200,
        predictedLayby: layby
    )
    let updated = try await client.applySnapshot(snapshot)
    #expect(updated.status == .rehearsed)
    #expect(updated.predictedLayby?.stop.label == "E2E Layby A1")

    let active = try await client.activeTrip(forVehicleId: vehicle.id)
    #expect(active?.id == trip.id)
    #expect(active?.status == .rehearsed)

    let briefContext = TripBriefContext.from(fleetTrip: updated, vehicleLabel: vehicle.label)
    let briefText = TripBriefFormatter.plainText(from: briefContext)
    #expect(briefText.contains("E2E Artic"))
    #expect(briefText.contains("Rehearsed"))
    #expect(briefText.contains("E2E Layby A1"))
    #expect(briefText.contains("Felixstowe"))
}
