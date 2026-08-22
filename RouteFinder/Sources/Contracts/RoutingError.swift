import Foundation

/// Errors that can occur during route planning.
public enum RoutingError: Error, Sendable, Equatable {
    /// A location could not be resolved to a graph node.
    case locationNotFound(String)
    /// No feasible route exists due to a constraint.
    case noFeasibleRoute(constraint: String)
    /// Input validation failed.
    case invalidInput(String)
    /// The routing graph has not been loaded.
    case graphNotLoaded
    /// Map matching failed because the click is too far from any road.
    case snapTooFar(distance: Double, maxDistance: Double)
}

extension RoutingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .locationNotFound(let location):
            return "Could not find location: \(location)"
        case .noFeasibleRoute(let constraint):
            return "No feasible route found: \(constraint)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .graphNotLoaded:
            return "The routing graph has not been loaded. Please load a graph first."
        case .snapTooFar(let distance, let maxDistance):
            return String(format: "No road within %.0f m (nearest %.0f m away). Click closer to a road.", maxDistance, distance)
        }
    }
}
