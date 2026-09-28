import DataLayer
import Foundation

/// Pure labeling for Mac/web desk fleet health pills (parity with Android ``FleetConnectionGate``).
public enum FleetServerHealthLabel: Sendable {
    /// Whether the desk may show Connected.
    public static func isConnected(healthOk: Bool, authSucceeded: Bool) -> Bool {
        healthOk && authSucceeded
    }

    /// Operator-facing pill text.
    ///
    /// Distinguishes **Auth failed** (wrong/`--api-key` mismatch) from **Offline** (server down / LAN)
    /// so LAN demos do not look like “server down” when the key is wrong.
    public static func status(
        healthOk: Bool,
        authSucceeded: Bool,
        authErrorMessage: String? = nil,
        version: String? = nil
    ) -> String {
        if isConnected(healthOk: healthOk, authSucceeded: authSucceeded) {
            if let version, !version.isEmpty {
                return "Connected · v\(version)"
            }
            return "Connected"
        }
        if healthOk && !authSucceeded {
            let detail = authErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (detail?.isEmpty == false)
                ? detail!
                : "Fleet API key rejected. Check the shared key with the operator."
            return "Auth failed · \(message)"
        }
        return "Offline"
    }

    /// Whether a thrown error should be classified as auth failure (not offline).
    public static func isAuthFailure(_ error: Error) -> Bool {
        if let http = error as? HTTPFleetStoreError {
            if case .serverError(let status, _) = http, status == 401 || status == 403 {
                return true
            }
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("api key") || text.contains("unauthorized") || text.contains("401") || text.contains("403")
    }
}
