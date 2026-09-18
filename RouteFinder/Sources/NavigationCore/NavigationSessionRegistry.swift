import Foundation

/// Weak global holder for the active navigation session (phone UI ↔ CarPlay).
@MainActor
public enum NavigationSessionRegistry {
    /// Shared active navigation session, if any.
    public static weak var shared: NavigationSession?
}

/// Injection hooks for CarPlay (and other external navigation surfaces).
@MainActor
public enum CarPlayServices {
    /// Navigation session shared between phone UI and CarPlay.
    public static weak var navigationSession: NavigationSession?
    /// Optional hook to register CarPlay as a session delegate at connect time.
    public static var registerDelegate: ((NavigationSessionDelegate) -> Void)?
    /// Notifies waiting CarPlay scenes that a session is now available.
    public static var onSessionAvailable: (() -> Void)?
    /// Optional provider of human-readable origin/destination labels for CarPlay trips (e.g. fleet stop names).
    public static var routeEndpointLabels: (() -> (origin: String, destination: String)?)?
    /// Optional provider of a CarPlay route-choice title (e.g. `"Norwich → King's Lynn"` for fleet trips).
    public static var routeChoiceTitle: (() -> String?)?

    /// Publishes the active navigation session for CarPlay scene attachment.
    public static func publish(session: NavigationSession) {
        navigationSession = session
        NavigationSessionRegistry.shared = session
        onSessionAvailable?()
    }
}
