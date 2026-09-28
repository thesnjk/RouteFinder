import Contracts
import Foundation
import Testing

@Suite("DispatcherDeskLANBootstrap")
struct DispatcherDeskLANBootstrapTests {
    @Test func appliesDefaultLocalhostWhenURLUnset() throws {
        let suiteName = "DeskLANBootstrap-default-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        var savedKey: String?
        let outcome = try DispatcherDeskLANBootstrap.apply(
            apiKey: "  pilot-secret  ",
            defaults: defaults,
            saveAPIKey: { savedKey = $0 }
        )

        #expect(outcome.appliedDefaultURL)
        #expect(outcome.serverURL.absoluteString == "http://127.0.0.1:8080")
        #expect(outcome.didSaveAPIKey)
        #expect(savedKey == "pilot-secret")
        #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
        #expect(
            FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)?.absoluteString
                == "http://127.0.0.1:8080"
        )
        #expect(FleetWorkspaceSettings.loadFleetConnectionKind(defaults: defaults) == .lan)
    }

    @Test func doesNotOverwriteExistingRemoteURL() throws {
        let suiteName = "DeskLANBootstrap-preserve-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        let existing = URL(string: "http://192.168.1.10:8080")!
        FleetWorkspaceSettings.saveRemoteFleetConfiguration(
            useRemote: false,
            serverURL: existing,
            defaults: defaults
        )

        let outcome = try DispatcherDeskLANBootstrap.apply(
            apiKey: nil,
            defaults: defaults,
            saveAPIKey: { _ in Issue.record("Should not save empty API key") }
        )

        #expect(!outcome.appliedDefaultURL)
        #expect(outcome.serverURL == existing)
        #expect(!outcome.didSaveAPIKey)
        #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
        #expect(
            FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)?.absoluteString
                == "http://192.168.1.10:8080"
        )
    }

    @Test func preservesHostedHTTPSURLAndEnablesRemote() throws {
        let suiteName = "DeskLANBootstrap-hosted-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        FleetWorkspaceSettings.saveRemoteFleetConfiguration(
            useRemote: true,
            serverURL: URL(string: "https://fleet.example.com")!,
            defaults: defaults
        )

        let outcome = try DispatcherDeskLANBootstrap.apply(
            apiKey: "",
            defaults: defaults
        )

        #expect(!outcome.appliedDefaultURL)
        #expect(outcome.serverURL.absoluteString == "https://fleet.example.com")
        #expect(!outcome.didSaveAPIKey)
        #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
        #expect(FleetWorkspaceSettings.loadFleetConnectionKind(defaults: defaults) == .hosted)
    }

    @Test func emptyAPIKeyDoesNotCallSave() throws {
        let suiteName = "DeskLANBootstrap-empty-key-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        var saveCount = 0
        let outcome = try DispatcherDeskLANBootstrap.apply(
            apiKey: "   ",
            defaults: defaults,
            saveAPIKey: { _ in saveCount += 1 }
        )

        #expect(!outcome.didSaveAPIKey)
        #expect(saveCount == 0)
        #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
    }

    @Test func nilAPIKeyEnablesRemoteWithoutSave() throws {
        let suiteName = "DeskLANBootstrap-nil-key-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        var saveCount = 0
        let outcome = try DispatcherDeskLANBootstrap.apply(
            apiKey: nil,
            defaults: defaults,
            saveAPIKey: { _ in saveCount += 1 }
        )

        #expect(outcome.appliedDefaultURL)
        #expect(!outcome.didSaveAPIKey)
        #expect(saveCount == 0)
        #expect(FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults))
        #expect(
            FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)?.absoluteString
                == "http://127.0.0.1:8080"
        )
    }
}
