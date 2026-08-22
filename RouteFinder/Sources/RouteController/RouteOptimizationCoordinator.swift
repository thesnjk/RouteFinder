import Contracts
import CoreLocation
import DataLayer
import Foundation

/// Orchestrates waypoint validation, matrix fetch, TSP solve, and route rebuild.
@MainActor
public final class RouteOptimizationCoordinator {
    private let orsAPIKey: String?

    /// Creates a route optimization coordinator.
    public init(orsAPIKey: String? = VehicleProfileStore.loadORSAPIKey()) {
        self.orsAPIKey = orsAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates that all coordinates are resolved and distinct.
    public static func validate(
        origin: RoutingCoordinate?,
        destination: RoutingCoordinate?,
        intermediateStops: [RoutingCoordinate]
    ) throws {
        guard let origin, let destination else {
            throw RouteOptimizationCoordinatorError.unresolvedEndpoints
        }
        guard intermediateStops.count >= 1 else {
            throw RouteOptimizationCoordinatorError.insufficientStops
        }

        let all = [origin] + intermediateStops + [destination]
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                let a = CLLocationCoordinate2D(latitude: all[i].latitude, longitude: all[i].longitude)
                let b = CLLocationCoordinate2D(latitude: all[j].latitude, longitude: all[j].longitude)
                if Haversine.distance(from: a, to: b) < 50 {
                    throw RouteOptimizationCoordinatorError.duplicateStops
                }
            }
        }
    }

    /// Optimizes intermediate stop order using matrix-first TSP heuristics.
    public func optimize(
        request: RouteOptimizationCoordinatorRequest,
        onPhase: ((RouteOptimizationPhase) -> Void)? = nil
    ) async throws -> RouteOptimizationCoordinatorResult {
        onPhase?(.validating)
        try Self.validate(
            origin: request.origin,
            destination: request.destination,
            intermediateStops: request.intermediateStops
        )

        onPhase?(.fetchingMatrix)
        let engine = RouteOptimizationEngine(
            orsAPIKey: orsAPIKey,
            vehicleProfile: request.vehicleProfile
        )

        onPhase?(.solvingTSP)
        let result = try await engine.optimizeCoordinatorRequest(request)
        onPhase?(.completed)
        return result
    }
}

/// Errors during route optimization coordination.
public enum RouteOptimizationCoordinatorError: Error, Sendable, LocalizedError {
    case unresolvedEndpoints
    case insufficientStops
    case duplicateStops

    public var errorDescription: String? {
        switch self {
        case .unresolvedEndpoints:
            "Origin and destination must be resolved before optimizing."
        case .insufficientStops:
            "At least one intermediate stop is required for optimization."
        case .duplicateStops:
            "Two or more stops are within 50 meters of each other."
        }
    }
}

/// Haversine distance helper for validation.
private enum Haversine {
    static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
