import Foundation
import Security

/// Thin wrapper around Keychain generic-password items (data-protection Keychain).
///
/// Uses ``kSecUseDataProtectionKeychain`` and, inside a signed `.app`, the app’s
/// ``keychain-access-groups`` entitlement as ``kSecAttrAccessGroup`` so sandboxed
/// macOS builds can read/write their own items without falling through to the
/// legacy login Keychain (which re-prompts on every launch).
///
/// Legacy login-Keychain I/O is reserved for non-app hosts (`swift test`, bare
/// `swift run`) and for one-shot migration helpers.
public enum KeychainStore: Sendable {
    /// `errSecMissingEntitlement` — data-protection Keychain unavailable in this process.
    private static let missingEntitlementStatus: OSStatus = -34018

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case unexpectedStatus(OSStatus)
        case encodingFailed
        case decodingFailed

        public var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return Self.message(for: status)
            case .encodingFailed:
                return "Could not encode Keychain value."
            case .decodingFailed:
                return "Could not decode Keychain value."
            }
        }

        /// Whether the status means the user denied or cancelled Keychain access.
        public static func isAccessDenied(_ status: OSStatus) -> Bool {
            status == errSecAuthFailed || status == errSecUserCanceled
        }

        public var isAccessDenied: Bool {
            if case .unexpectedStatus(let status) = self {
                return Self.isAccessDenied(status)
            }
            return false
        }

        private static func message(for status: OSStatus) -> String {
            let system = SecCopyErrorMessageString(status, nil) as String?
            switch status {
            case errSecDuplicateItem:
                return "A Keychain item already exists for this account."
            case errSecAuthFailed, errSecUserCanceled:
                return "Keychain access was denied. Choose Always Allow in the Keychain prompt, then try again."
            case errSecInteractionNotAllowed:
                return "Unlock your Mac and try again (Keychain is locked)."
            case -34018: // errSecMissingEntitlement
                return "Keychain access is unavailable for this build. Run the signed RouteFinderMac app (not bare swift run), or use Forgot password to reset."
            default:
                if let system, !system.isEmpty {
                    return "Keychain error: \(system) (\(status))."
                }
                return "Keychain error (\(status))."
            }
        }
    }

    /// True when running inside a real `.app` bundle (Xcode RouteFinderMac / packaged app).
    public static var isAppBundleHost: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    /// Legacy login-Keychain fallback is only for test / bare-executable hosts.
    public static var allowsLegacyKeychainFallback: Bool {
        !isAppBundleHost
    }

    /// First `keychain-access-groups` entitlement entry, if any (nil outside entitled `.app`).
    public static var keychainAccessGroup: String? {
        resolvedAccessGroup
    }

    private static let resolvedAccessGroup: String? = {
        guard isAppBundleHost else { return nil }
        return firstKeychainAccessGroupFromEntitlements()
    }()

    /// Stores UTF-8 string data for the given service/account pair.
    public static func set(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw Error.encodingFailed
        }
        try setData(data, service: service, account: account)
    }

    /// Stores raw data, preferring the data-protection Keychain.
    public static func setData(_ data: Data, service: String, account: String) throws {
        do {
            try setData(data, service: service, account: account, useDataProtection: true)
            if allowsLegacyKeychainFallback {
                try? deleteLegacyItem(service: service, account: account)
            }
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            guard allowsLegacyKeychainFallback else { throw Error.unexpectedStatus(status) }
            try setData(data, service: service, account: account, useDataProtection: false)
        }
    }

    /// Loads a UTF-8 string for the given service/account pair.
    public static func get(service: String, account: String) throws -> String? {
        guard let data = try getData(service: service, account: account) else {
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw Error.decodingFailed
        }
        return string
    }

    /// Loads raw data from the data-protection Keychain.
    ///
    /// Inside a signed `.app`, never touches the legacy login Keychain (avoids
    /// recurring password prompts). Non-app hosts may fall back and migrate.
    public static func getData(service: String, account: String) throws -> Data? {
        do {
            if let data = try copyMatching(
                service: service,
                account: account,
                useDataProtection: true
            ) {
                return data
            }
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            guard allowsLegacyKeychainFallback else { throw Error.unexpectedStatus(status) }
            return try copyMatching(
                service: service,
                account: account,
                useDataProtection: false
            )
        }

        // Signed .app: miss means empty — do not probe legacy (that re-prompts forever).
        guard allowsLegacyKeychainFallback else {
            return nil
        }

        guard let legacy = try copyMatching(
            service: service,
            account: account,
            useDataProtection: false
        ) else {
            return nil
        }

        do {
            try setData(legacy, service: service, account: account, useDataProtection: true)
            try? deleteLegacyItem(service: service, account: account)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            // Keep serving legacy until a signed app can migrate.
        }

        return legacy
    }

    /// Reads a single legacy login-Keychain item (no data-protection / access group).
    ///
    /// Used only for one-shot migration into the data-protection Keychain.
    public static func getLegacyData(service: String, account: String) throws -> Data? {
        try copyMatching(service: service, account: account, useDataProtection: false)
    }

    /// One-shot: copy a legacy item into DP (with access group) and delete the legacy copy.
    ///
    /// No-op if DP already has data or legacy is empty. Safe to call repeatedly.
    public static func migrateLegacyItemIfNeeded(service: String, account: String) throws {
        do {
            if let existing = try copyMatching(
                service: service,
                account: account,
                useDataProtection: true
            ), !existing.isEmpty {
                try? deleteLegacyItem(service: service, account: account)
                return
            }
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            // Non-app host cannot use DP — leave legacy alone.
            return
        }

        guard let legacy = try getLegacyData(service: service, account: account),
              !legacy.isEmpty else {
            return
        }
        do {
            try setData(legacy, service: service, account: account, useDataProtection: true)
            try? deleteLegacyItem(service: service, account: account)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            // Non-app host: already on legacy.
        }
    }

    /// Deletes the item for the given service/account pair (DP and, when allowed, legacy).
    public static func delete(service: String, account: String) throws {
        do {
            try deleteItem(service: service, account: account, useDataProtection: true)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            guard allowsLegacyKeychainFallback else { throw Error.unexpectedStatus(status) }
        }
        try? deleteLegacyItem(service: service, account: account)
    }

    /// Deletes all generic-password items for the given service (DP and legacy).
    public static func deleteAll(service: String) throws {
        do {
            try deleteAllItems(service: service, useDataProtection: true)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            guard allowsLegacyKeychainFallback else { throw Error.unexpectedStatus(status) }
        }
        try deleteAllLegacyItems(service: service)
    }

    /// Removes only legacy (non–data-protection) items for the service.
    public static func deleteAllLegacyItems(service: String) throws {
        try deleteAllItems(service: service, useDataProtection: false)
    }

    // MARK: - Internals

    /// Builds a base SecItem query. Exposed for unit tests of attribute shape.
    public static func baseQuery(
        service: String,
        account: String?,
        useDataProtection: Bool
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        if useDataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
            if let group = keychainAccessGroup {
                query[kSecAttrAccessGroup as String] = group
            }
        }
        return query
    }

    private static func firstKeychainAccessGroupFromEntitlements() -> String? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        guard let value = SecTaskCopyValueForEntitlement(
            task,
            "keychain-access-groups" as CFString,
            nil
        ) else {
            return nil
        }
        if let groups = value as? [String], let first = groups.first, !first.isEmpty {
            return first
        }
        if let single = value as? String, !single.isEmpty {
            return single
        }
        return nil
    }

    private static func setData(
        _ data: Data,
        service: String,
        account: String,
        useDataProtection: Bool
    ) throws {
        let query = baseQuery(service: service, account: account, useDataProtection: useDataProtection)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw Error.unexpectedStatus(addStatus)
            }
            return
        }
        throw Error.unexpectedStatus(status)
    }

    private static func copyMatching(
        service: String,
        account: String,
        useDataProtection: Bool
    ) throws -> Data? {
        var query = baseQuery(service: service, account: account, useDataProtection: useDataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw Error.unexpectedStatus(status)
        }
        return item as? Data
    }

    private static func deleteItem(
        service: String,
        account: String,
        useDataProtection: Bool
    ) throws {
        let query = baseQuery(service: service, account: account, useDataProtection: useDataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw Error.unexpectedStatus(status)
    }

    private static func deleteLegacyItem(service: String, account: String) throws {
        try deleteItem(service: service, account: account, useDataProtection: false)
    }

    private static func deleteAllItems(service: String, useDataProtection: Bool) throws {
        let query = baseQuery(service: service, account: nil, useDataProtection: useDataProtection)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw Error.unexpectedStatus(status)
    }
}
