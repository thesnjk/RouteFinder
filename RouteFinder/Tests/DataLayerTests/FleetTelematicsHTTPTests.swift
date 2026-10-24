import Contracts
import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

/// HTTP coverage for `POST /v1/telematics/ingest` and `GET /v1/telematics/pings` on the LAN fleet server.
@Test func fleetTelematicsIngestViaHTTP() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetTelematicsHTTP-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    // Dedicated port — must not collide with FleetProxyTests (18094–18096) or FleetSSETests.
    let port = 18100
    let store = DiskFleetStore(storageDirectory: storageDir)
    let router = FleetRouterBuilder.buildRouter(store: store, apiKey: nil)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    let serverTask = Task {
        try? await app.runService()
    }
    defer { serverTask.cancel() }

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    try await waitForFleetServerReady(baseURL: baseURL)

    let vehicleId = UUID()
    let body = TelematicsIngestRequest(
        vehicleId: vehicleId,
        latitude: 52.63,
        longitude: 1.3,
        recordedAt: Date(timeIntervalSince1970: 1_720_000_000),
        provider: "geotab",
        vehicleLabel: "Artic HTTP"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    var request = URLRequest(url: baseURL.appendingPathComponent("v1/telematics/ingest"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)
    let http = try #require(response as? HTTPURLResponse)
    #expect(http.statusCode == 200)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let ping = try decoder.decode(TelematicsVehiclePing.self, from: data)
    #expect(ping.provider == .geotab)
    #expect(ping.vehicleLabel == "Artic HTTP")
    #expect(ping.latitude == 52.63)
    #expect(ping.longitude == 1.3)

    let latest = try await store.latestTelematicsPings()
    #expect(latest.count == 1)
    #expect(latest.first?.vehicleLabel == "Artic HTTP")

    var getRequest = URLRequest(url: baseURL.appendingPathComponent("v1/telematics/pings"))
    getRequest.httpMethod = "GET"
    let (getData, getResponse) = try await URLSession.shared.data(for: getRequest)
    let getHTTP = try #require(getResponse as? HTTPURLResponse)
    #expect(getHTTP.statusCode == 200)
    let listed = try decoder.decode([TelematicsVehiclePing].self, from: getData)
    #expect(listed.count == 1)
    #expect(listed.first?.vehicleLabel == "Artic HTTP")
    #expect(listed.first?.provider == .geotab)

    var limited = URLRequest(
        url: baseURL.appendingPathComponent("v1/telematics/pings").appending(queryItems: [
            URLQueryItem(name: "limit", value: "1"),
        ])
    )
    limited.httpMethod = "GET"
    let (limitedData, limitedResponse) = try await URLSession.shared.data(for: limited)
    let limitedHTTP = try #require(limitedResponse as? HTTPURLResponse)
    #expect(limitedHTTP.statusCode == 200)
    let limitedList = try decoder.decode([TelematicsVehiclePing].self, from: limitedData)
    #expect(limitedList.count == 1)
}
