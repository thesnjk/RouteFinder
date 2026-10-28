import Contracts
import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

/// HTTP coverage for `POST/GET /v1/tacho/advisory` on the LAN fleet server.
@Test func fleetPartnerTachoAdvisoryViaHTTP() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetPartnerTachoHTTP-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18101
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

    var missing = URLRequest(url: baseURL.appendingPathComponent("v1/tacho/advisory"))
    missing.httpMethod = "GET"
    let (_, missingResponse) = try await URLSession.shared.data(for: missing)
    let missingHTTP = try #require(missingResponse as? HTTPURLResponse)
    #expect(missingHTTP.statusCode == 404)

    let body = PartnerTachoIngestRequest(
        remainingContinuousDriveSeconds: 3600,
        remainingDailyDriveSeconds: 18_000,
        remainingWeeklyDriveSeconds: 50_000,
        recordedAt: Date(timeIntervalSince1970: 1_720_000_000),
        provider: "geotab",
        vehicleLabel: "Unit 9"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    var post = URLRequest(url: baseURL.appendingPathComponent("v1/tacho/advisory"))
    post.httpMethod = "POST"
    post.setValue("application/json", forHTTPHeaderField: "Content-Type")
    post.httpBody = try encoder.encode(body)

    let (postData, postResponse) = try await URLSession.shared.data(for: post)
    let postHTTP = try #require(postResponse as? HTTPURLResponse)
    #expect(postHTTP.statusCode == 200)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let advisory = try decoder.decode(PartnerTachoAdvisory.self, from: postData)
    #expect(advisory.remainingContinuousDriveSeconds == 3600)
    #expect(advisory.provider == "geotab")
    #expect(advisory.vehicleLabel == "Unit 9")

    var get = URLRequest(url: baseURL.appendingPathComponent("v1/tacho/advisory"))
    get.httpMethod = "GET"
    let (getData, getResponse) = try await URLSession.shared.data(for: get)
    let getHTTP = try #require(getResponse as? HTTPURLResponse)
    #expect(getHTTP.statusCode == 200)
    let listed = try decoder.decode(PartnerTachoAdvisory.self, from: getData)
    #expect(listed.vehicleLabel == "Unit 9")

    let fromStore = try await store.latestPartnerTacho()
    #expect(fromStore?.vehicleLabel == "Unit 9")
}
