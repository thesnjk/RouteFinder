import Contracts
import Foundation

/// Lifecycle events emitted during waypoint sequence optimization.
public enum RouteOptimizationPhase: Sendable, Equatable {
    case validating
    case fetchingMatrix
    case solvingTSP
    case applyingOrder
    case routingGeometry
    case completed
    case failed(String)
}

/// Request to optimize intermediate stop order.
public struct RouteOptimizationCoordinatorRequest: Sendable {
    /// Fixed route origin coordinate.
    public let origin: RoutingCoordinate
    /// Fixed route destination coordinate.
    public let destination: RoutingCoordinate
    /// Intermediate via stops to permute.
    public let intermediateStops: [RoutingCoordinate]
    /// Vehicle profile for matrix and Vroom routing.
    public let vehicleProfile: VehicleSpecificationProfile
    /// Optimization tier selection.
    public let tier: OptimizationTier
    /// Whether to trigger route geometry rebuild after reorder.
    public let autoRouteAfterOptimize: Bool

    /// Creates a route optimization coordinator request.
    public init(
        origin: RoutingCoordinate,
        destination: RoutingCoordinate,
        intermediateStops: [RoutingCoordinate],
        vehicleProfile: VehicleSpecificationProfile,
        tier: OptimizationTier = .localPreferred,
        autoRouteAfterOptimize: Bool = true
    ) {
        self.origin = origin
        self.destination = destination
        self.intermediateStops = intermediateStops
        self.vehicleProfile = vehicleProfile
        self.tier = tier
        self.autoRouteAfterOptimize = autoRouteAfterOptimize
    }
}

/// Result of waypoint sequence optimization.
public struct RouteOptimizationCoordinatorResult: Sendable, Equatable {
    /// Optimized indices into the intermediate stop array.
    public let optimizedStopIndices: [Int]
    /// Whether local fallback tier was used.
    public let usedLocalTier: Bool
    /// Matrix fetch duration in milliseconds.
    public let matrixFetchDurationMs: Int
    /// TSP solve duration in milliseconds.
    public let optimizationDurationMs: Int

    /// Creates a route optimization coordinator result.
    public init(
        optimizedStopIndices: [Int],
        usedLocalTier: Bool,
        matrixFetchDurationMs: Int,
        optimizationDurationMs: Int
    ) {
        self.optimizedStopIndices = optimizedStopIndices
        self.usedLocalTier = usedLocalTier
        self.matrixFetchDurationMs = matrixFetchDurationMs
        self.optimizationDurationMs = optimizationDurationMs
    }
}
