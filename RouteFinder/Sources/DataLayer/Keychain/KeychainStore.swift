import Foundation
import Security

/// Thin wrapper around Keychain generic-password items (data-protection Keychain).
///
/// Uses ``kSecUseDataProtectionKeychain`` so items are not bound to the creating
/// binary’s legacy Keychain ACL (which breaks across debug / ad-hoc rebuilds).
/// Falls back to the legacy Keychain when the process lacks Keychain entitlements
/// (e.g. `swift test` host), still migrating legacy → DP when DP is available.
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
                return "Keychain access is unavailable for this build. Try rebuilding, or use Forgot password to reset."
            default:
                if let system, !system.isEmpty {
                    return "Keychain error: \(system) (\(status))."
                }
                return "Keychain error (\(status))."
            }
        }
    }

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
            try? deleteLegacyItem(service: service, account: account)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
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

    /// Loads raw data, preferring the data-protection Keychain and migrating legacy items.
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
            // DP unavailable in this process — read legacy only.
            return try copyMatching(
                service: service,
                account: account,
                useDataProtection: false
            )
        }

        // One-shot migration from legacy file Keychain (ACL-bound to old code signatures).
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

    /// Deletes the item for the given service/account pair (DP and legacy).
    public static func delete(service: String, account: String) throws {
        do {
            try deleteItem(service: service, account: account, useDataProtection: true)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            // Ignore; delete legacy below.
        }
        try deleteLegacyItem(service: service, account: account)
    }

    /// Deletes all generic-password items for the given service (DP and legacy).
    public static func deleteAll(service: String) throws {
        do {
            try deleteAllItems(service: service, useDataProtection: true)
        } catch Error.unexpectedStatus(let status) where status == missingEntitlementStatus {
            // Ignore; delete legacy below.
        }
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
        }
        return query
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
