import Foundation

/// Execution tier for waypoint sequence optimization.
public enum OptimizationTier: String, Codable, Sendable, Hashable, CaseIterable {
    /// Prefer local heuristic on macOS; fall back to cloud when available.
    case localPreferred
    /// Cloud-only (ORS Vroom); used on iOS or when forced.
    case cloudOnly
    /// Local heuristic only (macOS); no network call.
    case localOnly
}

/// Request to reorder intermediate stops for minimum travel distance.
public struct WaypointOptimizationRequest: Sendable, Hashable {
    /// Fixed route origin.
    public let origin: RoutingCoordinate
    /// Fixed route destination.
    public let destination: RoutingCoordinate
    /// Intermediate via stops to permute (origin/destination excluded).
    public let intermediateStops: [RoutingCoordinate]
    /// Rich optimization waypoints with time windows and demand (optional).
    public let optimizationWaypoints: [OptimizationWaypoint]?
    /// Driver break rules for Vroom scheduling (optional).
    public let breakRules: [OptimizationBreakRule]?
    /// Precomputed distance matrix for local fallback (optional).
    public let distanceMatrix: [[Double]]?
    /// Vehicle gross weight capacity in tonnes for ORS Vroom payload.
    public let vehicleCapacityTonnes: Double?
    /// Which optimization tier to attempt.
    public let tier: OptimizationTier

    /// Creates a waypoint optimization request.
    public init(
        origin: RoutingCoordinate,
        destination: RoutingCoordinate,
        intermediateStops: [RoutingCoordinate],
        optimizationWaypoints: [OptimizationWaypoint]? = nil,
        breakRules: [OptimizationBreakRule]? = nil,
        distanceMatrix: [[Double]]? = nil,
        vehicleCapacityTonnes: Double? = nil,
        tier: OptimizationTier = .localPreferred
    ) {
        self.origin = origin
        self.destination = destination
        self.intermediateStops = intermediateStops
        self.optimizationWaypoints = optimizationWaypoints
        self.breakRules = breakRules
        self.distanceMatrix = distanceMatrix
        self.vehicleCapacityTonnes = vehicleCapacityTonnes
        self.tier = tier
    }
}
