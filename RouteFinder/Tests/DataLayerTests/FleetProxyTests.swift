import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

private func startFleetServerWithORS(
    port: Int,
    storageDirectory: URL,
    orsAPIKey: String?
) -> Task<Void, Never> {
    let store = DiskFleetStore(storageDirectory: storageDirectory)
    let router = FleetRouterBuilder.buildRouter(
        store: store,
        apiKey: nil,
        orsAPIKey: orsAPIKey,
        eventHub: FleetEventHub(heartbeatIntervalSeconds: 60)
    )
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    return Task {
        try? await app.runService()
    }
}

@Test func fleetProxyStatusReportsORSConfigured() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetProxyTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18094
    let serverTask = startFleetServerWithORS(port: port, storageDirectory: storageDir, orsAPIKey: "test-ors-key")
    defer { serverTask.cancel() }

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    try await waitForFleetServerReady(baseURL: baseURL)

    let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("v1/proxy/status"))
    let http = try #require(response as? HTTPURLResponse)
    #expect(http.statusCode == 200)

    let status = try JSONDecoder().decode(FleetProxyStatusResponse.self, from: data)
    #expect(status.orsConfigured)
    #expect(status.routeDailyCap > 0)
    #expect(status.routesToday == 0)
    #expect(status.overpassConfigured)
}

@Test func fleetProxyStatusReportsForecastKeys() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetProxyForecast-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18096
    let store = DiskFleetStore(storageDirectory: storageDir)
    let router = FleetRouterBuilder.buildRouter(
        store: store,
        apiKey: nil,
        orsAPIKey: nil,
        tomTomAPIKey: "tt-test",
        openWeatherAPIKey: "ow-test",
        eventHub: FleetEventHub(heartbeatIntervalSeconds: 60)
    )
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    let serverTask = Task { try? await app.runService() }
    defer { serverTask.cancel() }

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    try await waitForFleetServerReady(baseURL: baseURL)
    let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("v1/proxy/status"))
    let http = try #require(response as? HTTPURLResponse)
    #expect(http.statusCode == 200)
    let status = try JSONDecoder().decode(FleetProxyStatusResponse.self, from: data)
    #expect(status.tomTomConfigured)
    #expect(status.openWeatherConfigured)
    #expect(status.overpassConfigured)
}

@Test func fleetProxyStatusReportsORSNotConfigured() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetProxyTests-off-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18095
    let serverTask = startFleetServerWithORS(port: port, storageDirectory: storageDir, orsAPIKey: nil)
    defer { serverTask.cancel() }

    let baseURL = URL(string: "http://127.0.0.1:\(port)")!
    try await waitForFleetServerReady(baseURL: baseURL)

    let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("v1/proxy/status"))
    let http = try #require(response as? HTTPURLResponse)
    #expect(http.statusCode == 200)

    let status = try JSONDecoder().decode(FleetProxyStatusResponse.self, from: data)
    #expect(!status.orsConfigured)
}

@Test func fleetProxyUsageMeterPersistsAcrossRestart() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetProxyMeterPersist-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let budget = FleetProxyUsageBudget(routeDailyCap: 50, geocodeDailyCap: 50)
    let first = FleetProxyUsageMeter(budget: budget, storageDirectory: storageDir)
    await first.record(.orsRoute)
    await first.record(.orsRoute)
    await first.record(.orsGeocode)
    let mid = await first.status(orsConfigured: true)
    #expect(mid.routesToday == 2)
    #expect(mid.geocodeToday == 1)

    let second = FleetProxyUsageMeter(budget: budget, storageDirectory: storageDir)
    let restored = await second.status(orsConfigured: true)
    #expect(restored.routesToday == 2)
    #expect(restored.geocodeToday == 1)
    #expect(restored.routeDailyCap == 50)
}
