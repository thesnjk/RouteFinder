import Foundation

/// High-level navigation session lifecycle phase.
public enum NavigationPhase: String, Sendable, Equatable {
    /// No active navigation session.
    case idle
    /// Route loaded but not yet tracking position.
    case routeLoaded
    /// Actively tracking position along the route.
    case navigating
    /// Navigation completed at destination.
    case completed
}
