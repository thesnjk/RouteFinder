import Contracts
import DataLayer
import Foundation
import Testing

@Test func saveRemoteFleetConfigurationPostsNotification() {
    let suiteName = "FleetStoreHotReloadTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { UserDefaults.standard.removeSuite(named: suiteName) }

    var received = false
    let observer = NotificationCenter.default.addObserver(
        forName: .fleetStoreConfigurationDidChange,
        object: nil,
        queue: nil
    ) { _ in
        received = true
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: true,
        serverURL: URL(string: "http://127.0.0.1:8080")!,
        defaults: defaults
    )

    #expect(received)
    #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
    #expect(FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)?.absoluteString == "http://127.0.0.1:8080")
}

@Test func saveRemoteFleetConfigurationClearsServerURL() {
    let suiteName = "FleetStoreHotReloadTests-clear-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { UserDefaults.standard.removeSuite(named: suiteName) }

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: false,
        serverURL: nil,
        defaults: defaults
    )

    #expect(!FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
    #expect(FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults) == nil)
}

@Test func fleetStoreFactoryReflectsSavedRemoteConfiguration() {
    let suiteName = "FleetStoreHotReloadTests-factory-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { UserDefaults.standard.removeSuite(named: suiteName) }

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: true,
        serverURL: URL(string: "http://127.0.0.1:8080")!,
        defaults: defaults
    )
    let remoteStore = FleetStoreFactory.makeStore(defaults: defaults)
    #expect(remoteStore is HTTPFleetStore)

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: false,
        serverURL: nil,
        defaults: defaults
    )
    let localStore = FleetStoreFactory.makeStore(defaults: defaults)
    #expect(localStore is DiskFleetStore)
}

@Test func httpsFleetURLInfersHostedConnectionKind() {
    let suiteName = "FleetStoreHotReloadTests-hosted-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { UserDefaults.standard.removeSuite(named: suiteName) }

    FleetWorkspaceSettings.saveRemoteFleetConfiguration(
        useRemote: true,
        serverURL: URL(string: "https://fleet.example.com")!,
        defaults: defaults
    )

    #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
    #expect(
        FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)?.absoluteString
            == "https://fleet.example.com"
    )
    #expect(FleetWorkspaceSettings.loadFleetConnectionKind(defaults: defaults) == .hosted)
}
