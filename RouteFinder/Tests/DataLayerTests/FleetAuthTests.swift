import Contracts
import DataLayer
import FleetServerCore
import Foundation
import Hummingbird
import Testing

private func startFleetServer(
    port: Int,
    storageDirectory: URL,
    apiKey: String?
) -> Task<Void, Never> {
    let store = DiskFleetStore(storageDirectory: storageDirectory)
    let router = FleetRouterBuilder.buildRouter(store: store, apiKey: apiKey)
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port))
    )
    return Task {
        try? await app.runService()
    }
}

@Test func fleetHealthEndpointRemainsPublicWhenAPIKeyConfigured() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetAuthTests-health-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18081
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: "secret-key")
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let client = HTTPFleetStore(baseURL: URL(string: "http://127.0.0.1:\(port)")!)
    let health = try await client.checkHealth()
    #expect(health.ok)
}

@Test func fleetProtectedRoutesRejectMissingAPIKey() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetAuthTests-unauth-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18082
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: "secret-key")
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let client = HTTPFleetStore(baseURL: URL(string: "http://127.0.0.1:\(port)")!)
    do {
        _ = try await client.orgs()
        Issue.record("Expected unauthorized error for missing API key.")
    } catch let error as HTTPFleetStoreError {
        guard case .serverError(let status, let body) = error else {
            Issue.record("Unexpected error type: \(error)")
            return
        }
        #expect(status == 401)
        #expect(body.contains("Unauthorized"))
    }
}

@Test func fleetProtectedRoutesAcceptBearerAPIKey() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetAuthTests-auth-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18083
    let apiKey = "fleet-test-secret"
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: apiKey)
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let client = HTTPFleetStore(
        baseURL: URL(string: "http://127.0.0.1:\(port)")!,
        apiKey: apiKey
    )
    let org = try await client.createOrg(name: "Auth Test Ltd")
    #expect(org.name == "Auth Test Ltd")
    #expect(try await client.orgs().count == 1)
}

@Test func fleetProtectedRoutesRejectWrongAPIKey() async throws {
    let storageDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetAuthTests-wrong-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: storageDir) }

    let port = 18084
    let serverTask = startFleetServer(port: port, storageDirectory: storageDir, apiKey: "expected-key")
    defer { serverTask.cancel() }
    try await Task.sleep(nanoseconds: 300_000_000)

    let client = HTTPFleetStore(
        baseURL: URL(string: "http://127.0.0.1:\(port)")!,
        apiKey: "wrong-key"
    )
    do {
        _ = try await client.orgs()
        Issue.record("Expected unauthorized error for wrong API key.")
    } catch let error as HTTPFleetStoreError {
        guard case .serverError(let status, _) = error else {
            Issue.record("Unexpected error type: \(error)")
            return
        }
        #expect(status == 401)
    }
}

@Test func fleetStoreFactoryPassesKeychainAPIKey() throws {
    let suiteName = "FleetAuthTests-factory-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { UserDefaults.standard.removeSuite(named: suiteName) }

    try FleetServerCredentials.saveAPIKey("factory-test-key")
    defer { try? FleetServerCredentials.saveAPIKey(nil) }

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: true,
        serverURL: URL(string: "http://127.0.0.1:8080")!,
        defaults: defaults
    )
    let store = FleetStoreFactory.makeStore(defaults: defaults)
    #expect(store is HTTPFleetStore)
}

@Test func fleetServerTLSLoadsPEMCertificateAndKey() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetAuthTests-tls-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let certPath = directory.appendingPathComponent("cert.pem")
    let keyPath = directory.appendingPathComponent("key.pem")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
    process.arguments = [
        "req", "-x509", "-newkey", "rsa:2048",
        "-keyout", keyPath.path,
        "-out", certPath.path,
        "-days", "1", "-nodes",
        "-subj", "/CN=localhost",
    ]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let tlsConfiguration = try FleetServerTLS.makeServerConfiguration(
        certificatePath: certPath,
        privateKeyPath: keyPath
    )
    #expect(!tlsConfiguration.certificateChain.isEmpty)
}
