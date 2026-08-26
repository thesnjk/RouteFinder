import Contracts
import Foundation

/// Keychain-backed credentials for the remote fleet HTTP server.
public enum FleetServerCredentials {
    private static let service = "com.routefinder.fleet"
    private static let account = "fleetServerAPIKey"

    /// Loads the fleet server API key from the Keychain.
    public static func loadAPIKey() throws -> String? {
        try KeychainStore.get(service: service, account: account)
    }

    /// Persists or clears the fleet server API key and notifies store listeners.
    public static func saveAPIKey(_ key: String?) throws {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            try KeychainStore.set(trimmed, service: service, account: account)
        } else {
            try KeychainStore.delete(service: service, account: account)
        }
        NotificationCenter.default.post(name: .fleetStoreConfigurationDidChange, object: nil)
    }
}
