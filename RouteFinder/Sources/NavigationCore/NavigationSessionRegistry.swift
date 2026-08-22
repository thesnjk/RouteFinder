import Foundation

/// Global weak registry for sharing the active navigation session across UI surfaces.
@MainActor
public enum NavigationSessionRegistry {
    /// Currently active navigation session, when configured.
    public static weak var shared: NavigationSession?
}
