import Foundation
import Security

/// Thin wrapper around macOS Keychain generic-password items.
public enum KeychainStore: Sendable {
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

        private static func message(for status: OSStatus) -> String {
            let system = SecCopyErrorMessageString(status, nil) as String?
            switch status {
            case errSecDuplicateItem:
                return "A Keychain item already exists for this account."
            case errSecAuthFailed, errSecUserCanceled:
                return "Keychain access was denied. Allow RouteFinder in the Keychain prompt, then try again."
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

    /// Stores raw data for the given service/account pair.
    public static func setData(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

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

    /// Loads raw data for the given service/account pair.
    public static func getData(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
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

    /// Deletes the item for the given service/account pair.
    public static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw Error.unexpectedStatus(status)
    }

    /// Deletes all generic-password items for the given service.
    public static func deleteAll(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw Error.unexpectedStatus(status)
    }
}
