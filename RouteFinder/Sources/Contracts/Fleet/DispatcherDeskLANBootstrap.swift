import Foundation

/// Wires Mac dispatcher onboarding onto the office LAN fleet server (not Local disk).
///
/// Strangers who **Copy server command** then **Open Dispatch** must push into the same
/// `RouteFinderFleetServer` that drivers pair to. This enables remote fleet, defaults the
/// URL to localhost only when unset, and optionally persists the shared API key.
public enum DispatcherDeskLANBootstrap: Sendable {
    /// Default desk URL when the operator runs the fleet server on this Mac (`--port 8080`).
    public static let defaultLANServerURL = URL(string: "http://127.0.0.1:8080")!

    /// Result of applying LAN desk bootstrap.
    public struct Outcome: Sendable, Equatable {
        /// Whether the default localhost URL was written because none was saved.
        public let appliedDefaultURL: Bool
        /// URL now configured for the remote fleet store.
        public let serverURL: URL
        /// Whether a non-empty API key was passed through to `saveAPIKey`.
        public let didSaveAPIKey: Bool

        public init(appliedDefaultURL: Bool, serverURL: URL, didSaveAPIKey: Bool) {
            self.appliedDefaultURL = appliedDefaultURL
            self.serverURL = serverURL
            self.didSaveAPIKey = didSaveAPIKey
        }
    }

    /// Enables remote fleet for the desk.
    ///
    /// - Parameters:
    ///   - apiKey: Shared secret from onboarding (trimmed). Empty / nil skips Keychain write.
    ///   - defaults: Preference store (injectable for tests).
    ///   - saveAPIKey: Persist key (typically `FleetServerCredentials.saveAPIKey`). Nil skips.
    /// - Returns: What was applied (default URL vs preserve existing).
    @discardableResult
    public static func apply(
        apiKey: String?,
        defaults: UserDefaults = .standard,
        saveAPIKey: ((String) throws -> Void)? = nil
    ) throws -> Outcome {
        let existing = FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults)
        let appliedDefaultURL = existing == nil
        let serverURL = existing ?? defaultLANServerURL

        FleetWorkspaceSettings.saveRemoteFleetConfiguration(
            useRemote: true,
            serverURL: serverURL,
            defaults: defaults
        )
        if appliedDefaultURL {
            FleetWorkspaceSettings.saveFleetConnectionKind(.lan, defaults: defaults)
        }

        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var didSave = false
        if !trimmed.isEmpty, let saveAPIKey {
            try saveAPIKey(trimmed)
            didSave = true
        }

        return Outcome(
            appliedDefaultURL: appliedDefaultURL,
            serverURL: serverURL,
            didSaveAPIKey: didSave
        )
    }
}
