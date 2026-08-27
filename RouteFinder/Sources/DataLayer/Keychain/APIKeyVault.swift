import Foundation

/// Secret kinds stored per local user in the Keychain.
public enum APIKeyKind: String, Sendable, CaseIterable {
    case ors
    case openWeather
    case dvla
    case tomTom
    case regCheckUsername
}

/// Per-user Keychain vault for API credentials.
public struct APIKeyVault: Sendable {
    public let userID: String

    private static let servicePrefix = "com.routefinder.vault"

    public init(userID: String) {
        self.userID = userID
    }

    private var service: String {
        "\(Self.servicePrefix).\(userID)"
    }

    /// Returns whether a non-empty secret exists for the kind.
    public func hasValue(for kind: APIKeyKind) throws -> Bool {
        guard let value = try load(kind) else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Loads a secret for the kind, if present.
    public func load(_ kind: APIKeyKind) throws -> String? {
        try KeychainStore.get(service: service, account: kind.rawValue)
    }

    /// Loads every non-empty secret stored for this user.
    public func loadAll() throws -> [APIKeyKind: String] {
        var result: [APIKeyKind: String] = [:]
        for kind in APIKeyKind.allCases {
            guard let value = try load(kind)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                continue
            }
            result[kind] = value
        }
        return result
    }

    /// Migrates every vault account from the legacy login Keychain into data-protection storage.
    ///
    /// Call once after login so a single Allow session clears `com.routefinder.vault.<userID>`
    /// leftovers instead of re-prompting per key on later launches.
    public func migrateLegacyKeychainIfNeeded() throws {
        _ = try loadAll()
        try? KeychainStore.deleteAllLegacyItems(service: service)
    }

    /// Saves a secret for the kind. Empty values delete the item.
    public func save(_ value: String, for kind: APIKeyKind) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try KeychainStore.delete(service: service, account: kind.rawValue)
            return
        }
        try KeychainStore.set(trimmed, service: service, account: kind.rawValue)
    }

    /// Removes every vault item for this user.
    public func wipeAll() throws {
        for kind in APIKeyKind.allCases {
            try KeychainStore.delete(service: service, account: kind.rawValue)
        }
    }

    /// Copies legacy UserDefaults secrets into the vault, then clears them from UserDefaults.
    public func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) throws {
        let pairs: [(APIKeyKind, String)] = [
            (.ors, "RouteFinder.orsAPIKey"),
            (.openWeather, "RouteFinder.openWeatherAPIKey"),
            (.dvla, "RouteFinder.dvlaAPIKey"),
            (.tomTom, "RouteFinder.tomTomAPIKey"),
            (.regCheckUsername, "RouteFinder.regCheckUsername"),
        ]

        var migratedAny = false
        for (kind, defaultsKey) in pairs {
            guard let legacy = defaults.string(forKey: defaultsKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !legacy.isEmpty else {
                continue
            }
            let existing = try load(kind)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if existing.isEmpty {
                try save(legacy, for: kind)
            }
            defaults.removeObject(forKey: defaultsKey)
            migratedAny = true
        }

        if migratedAny {
            defaults.synchronize()
        }
    }
}
