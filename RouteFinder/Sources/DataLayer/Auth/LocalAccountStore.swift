import CommonCrypto
import Foundation
import Security

/// Local account record stored on-device (no cloud).
public struct LocalAccountRecord: Codable, Sendable, Equatable {
    public let userID: String
    public let email: String
    public let salt: Data
    public let passwordVerifier: Data
    public let createdAt: Date

    public init(userID: String, email: String, salt: Data, passwordVerifier: Data, createdAt: Date = Date()) {
        self.userID = userID
        self.email = email
        self.salt = salt
        self.passwordVerifier = passwordVerifier
        self.createdAt = createdAt
    }
}

/// Creates and verifies local email/password accounts using Keychain-backed storage.
public enum LocalAccountStore: Sendable {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case accountExists
        case accountMissing
        case invalidCredentials
        case invalidEmail
        case weakPassword
        case privacyConsentRequired
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .accountExists:
                return "An account already exists on this Mac. Log in instead."
            case .accountMissing:
                return "No local account found. Sign up to continue."
            case .invalidCredentials:
                return "Incorrect email or password."
            case .invalidEmail:
                return "Enter a valid email address."
            case .weakPassword:
                return "Password must be at least 8 characters."
            case .privacyConsentRequired:
                return "You must accept the privacy notice to create an account."
            case .encodingFailed:
                return "Could not read or save the local account record. Use Forgot password to erase it and sign up again."
            }
        }
    }

    private static let service = "com.routefinder.account"
    private static let accountKey = "primary"
    private static let iterations: UInt32 = 210_000

    /// Returns whether a local account is registered on this Mac.
    public static func hasAccount() throws -> Bool {
        try loadRecord() != nil
    }

    /// Returns whether a Keychain account item exists, even if it cannot be decoded.
    public static func accountItemExists() throws -> Bool {
        try KeychainStore.getData(service: service, account: accountKey) != nil
    }

    /// Loads the registered account, if any.
    public static func loadRecord() throws -> LocalAccountRecord? {
        guard let data = try KeychainStore.getData(service: service, account: accountKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(LocalAccountRecord.self, from: data)
        } catch {
            throw Error.encodingFailed
        }
    }

    /// Creates the first local account on this Mac.
    public static func signUp(email: String, password: String, privacyConsent: Bool) throws -> LocalAccountRecord {
        guard privacyConsent else {
            throw Error.privacyConsentRequired
        }
        let normalized = normalizeEmail(email)
        guard isValidEmail(normalized) else {
            throw Error.invalidEmail
        }
        guard password.count >= 8 else {
            throw Error.weakPassword
        }
        // Any Keychain item (valid or corrupt) blocks a second signup on this Mac.
        if try accountItemExists() {
            throw Error.accountExists
        }

        var salt = Data(count: 16)
        let saltStatus = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard saltStatus == errSecSuccess else {
            throw KeychainStore.Error.unexpectedStatus(saltStatus)
        }

        let verifier = try deriveVerifier(password: password, salt: salt)
        let record = LocalAccountRecord(
            userID: UUID().uuidString,
            email: normalized,
            salt: salt,
            passwordVerifier: verifier
        )
        try save(record)
        return record
    }

    /// Verifies credentials and returns the account on success.
    public static func login(email: String, password: String) throws -> LocalAccountRecord {
        guard let record = try loadRecord() else {
            throw Error.accountMissing
        }
        let normalized = normalizeEmail(email)
        guard record.email == normalized else {
            throw Error.invalidCredentials
        }
        let candidate = try deriveVerifier(password: password, salt: record.salt)
        guard constantTimeEquals(candidate, record.passwordVerifier) else {
            throw Error.invalidCredentials
        }
        return record
    }

    /// Deletes the local account record (does not wipe API key vault by itself).
    public static func deleteAccount() throws {
        try KeychainStore.delete(service: service, account: accountKey)
    }

    private static func save(_ record: LocalAccountRecord) throws {
        let data = try JSONEncoder().encode(record)
        try KeychainStore.setData(data, service: service, account: accountKey)
    }

    private static func deriveVerifier(password: String, salt: Data) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw Error.encodingFailed
        }
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw KeychainStore.Error.unexpectedStatus(OSStatus(status))
        }
        return derived
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhs, rhs) {
            diff |= a ^ b
        }
        return diff == 0
    }

    private static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".") && email.count >= 5
    }
}
