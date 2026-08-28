import Contracts
import DataLayer
import Foundation
import LocalAuthentication
import Observation

/// Owns local login state for the macOS app session.
@MainActor
@Observable
public final class SessionController {
    public enum Phase: Equatable {
        case loading
        case unauthenticated
        case authenticated
    }

    public private(set) var phase: Phase = .loading
    public private(set) var accountExists = false
    public private(set) var currentUserID: String?
    public private(set) var currentEmail: String?
    public private(set) var errorMessage: String?
    public private(set) var vault: APIKeyVault?
    /// Email pre-filled on the login form after a cancelled auto-unlock.
    public private(set) var prefillEmail: String = ""

    public init() {}

    /// Boots splash state and attempts device auto-unlock when allowed.
    public func bootstrap() async {
        phase = .loading
        errorMessage = nil
        prefillEmail = SessionWorkspaceSettings.loadLastEmail() ?? ""
        try? await Task.sleep(nanoseconds: 600_000_000)
        refreshAccountExists()

        if accountExists,
           !SessionWorkspaceSettings.loadRequireLoginEachLaunch(),
           let record = try? LocalAccountStore.loadRecord(),
           await deviceOwnerAuthenticated() {
            do {
                try unlock(record)
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        phase = .unauthenticated
    }

    /// Surfaces a user-visible auth error.
    public func reportError(_ message: String) {
        errorMessage = message
    }

    /// Creates a local account and unlocks the session.
    public func signUp(email: String, password: String, privacyConsent: Bool) {
        errorMessage = nil
        do {
            let record = try LocalAccountStore.signUp(
                email: email,
                password: password,
                privacyConsent: privacyConsent
            )
            try unlock(record)
        } catch let error as LocalAccountStore.Error {
            errorMessage = error.localizedDescription
            refreshAccountExists()
        } catch {
            errorMessage = error.localizedDescription
            refreshAccountExists()
        }
    }

    /// Logs into the existing local account.
    public func login(email: String, password: String) {
        errorMessage = nil
        do {
            let record = try LocalAccountStore.login(email: email, password: password)
            try unlock(record)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clears the in-memory session; Keychain secrets remain.
    public func logout() {
        currentUserID = nil
        currentEmail = nil
        vault = nil
        refreshAccountExists()
        phase = .unauthenticated
        errorMessage = nil
        prefillEmail = SessionWorkspaceSettings.loadLastEmail() ?? ""
    }

    /// Deletes the local account and wipes the Keychain vault.
    public func deleteAccount() {
        errorMessage = nil
        do {
            try wipeLocalAccountAndVault()
            currentUserID = nil
            currentEmail = nil
            vault = nil
            accountExists = false
            phase = .unauthenticated
            SessionWorkspaceSettings.clearRememberedSession()
            prefillEmail = ""
        } catch {
            errorMessage = error.localizedDescription
            refreshAccountExists()
        }
    }

    /// Erases the local account and API key vault after a forgotten-password confirmation.
    ///
    /// There is no email reset for local-only auth; the user must create a new account.
    public func resetForgottenPassword() {
        errorMessage = nil
        do {
            try wipeLocalAccountAndVault()
            currentUserID = nil
            currentEmail = nil
            vault = nil
            accountExists = false
            phase = .unauthenticated
            errorMessage = nil
            SessionWorkspaceSettings.clearRememberedSession()
            prefillEmail = ""
        } catch {
            errorMessage = error.localizedDescription
            refreshAccountExists()
        }
    }

    private func wipeLocalAccountAndVault() throws {
        if let userID = currentUserID {
            try APIKeyVault(userID: userID).wipeAll()
        } else if let record = try? LocalAccountStore.loadRecord() {
            try APIKeyVault(userID: record.userID).wipeAll()
        }
        try LocalAccountStore.deleteAccount()
    }

    private func refreshAccountExists() {
        do {
            accountExists = try LocalAccountStore.hasAccount()
        } catch {
            accountExists = (try? LocalAccountStore.accountItemExists()) ?? false
            if accountExists {
                errorMessage = "The local account on this Mac could not be read. Use Forgot password to erase it and create a new one."
            } else if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func unlock(_ record: LocalAccountRecord) throws {
        let keyVault = APIKeyVault(userID: record.userID)
        var keychainMessage: String?
        do {
            try keyVault.migrateFromUserDefaultsIfNeeded()
            try keyVault.migrateLegacyKeychainIfNeeded()
        } catch let error as KeychainStore.Error {
            keychainMessage = error.localizedDescription
        } catch {
            keychainMessage = error.localizedDescription
        }
        vault = keyVault
        currentUserID = record.userID
        currentEmail = record.email
        accountExists = true
        phase = .authenticated
        errorMessage = keychainMessage
        SessionWorkspaceSettings.saveLastUserID(record.userID)
        SessionWorkspaceSettings.saveLastEmail(record.email)
        prefillEmail = record.email
    }

    private func deviceOwnerAuthenticated() async -> Bool {
        let context = LAContext()
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock RouteFinder"
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
