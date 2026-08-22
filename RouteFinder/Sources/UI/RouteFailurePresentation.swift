import Contracts
import DataLayer
import Foundation
import RouteController

/// User-facing presentation for route calculation failures.
public struct RouteFailurePresentation: Identifiable, Equatable {
    /// Category of route failure for icon and styling.
    public enum Kind: Equatable {
        case hgvInfeasible
        case routeBlocked
        case coverage
        case snapFailed
        case generic
    }

    public let id = UUID()
    public let kind: Kind
    public let title: String
    public let message: String
    public let detail: String?

    public init(kind: Kind, title: String, message: String, detail: String? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.detail = detail
    }

    public static func == (lhs: RouteFailurePresentation, rhs: RouteFailurePresentation) -> Bool {
        lhs.kind == rhs.kind
            && lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.detail == rhs.detail
    }
}

/// Maps routing errors to modal presentation copy.
public enum RouteFailureMapper {
    /// Maps an error to a user-facing route failure presentation.
    public static func map(
        _ error: Error,
        vehicle: VehicleProfile,
        isHGVMode: Bool
    ) -> RouteFailurePresentation {
        if let routing = error as? RoutingError {
            return mapRoutingError(routing, vehicle: vehicle, isHGVMode: isHGVMode)
        }
        if let external = error as? ExternalRoutingError {
            return mapExternalError(external)
        }
        return RouteFailurePresentation(
            kind: .generic,
            title: "Route Failed",
            message: error.localizedDescription,
            detail: nil
        )
    }

    private static func mapRoutingError(
        _ error: RoutingError,
        vehicle: VehicleProfile,
        isHGVMode: Bool
    ) -> RouteFailurePresentation {
        switch error {
        case .noFeasibleRoute(let constraint):
            if isHGVMode, vehicle.height != nil {
                return RouteFailurePresentation(
                    kind: .hgvInfeasible,
                    title: "Route Unfeasible",
                    message: "Low bridge clearance detected on optimal corridor.",
                    detail: constraint
                )
            }
            return RouteFailurePresentation(
                kind: .generic,
                title: "Route Unfeasible",
                message: error.localizedDescription,
                detail: constraint
            )
        case .snapTooFar:
            return RouteFailurePresentation(
                kind: .snapFailed,
                title: "Cannot Snap to Road",
                message: error.localizedDescription,
                detail: nil
            )
        default:
            return RouteFailurePresentation(
                kind: .generic,
                title: "Route Failed",
                message: error.localizedDescription,
                detail: nil
            )
        }
    }

    private static func mapExternalError(_ error: ExternalRoutingError) -> RouteFailurePresentation {
        switch error {
        case .vehicleDimensionBlocked:
            return RouteFailurePresentation(
                kind: .routeBlocked,
                title: "Route Blocked",
                message: ExternalRoutingError.vehicleDimensionBlockedMessage,
                detail: error.serverReason
            )
        case .noRoute:
            return RouteFailurePresentation(
                kind: .hgvInfeasible,
                title: "Route Unfeasible",
                message: ExternalRoutingError.hgvNoRouteMessage,
                detail: error.serverReason
            )
        default:
            return RouteFailurePresentation(
                kind: .generic,
                title: "Route Failed",
                message: error.localizedDescription,
                detail: error.serverReason
            )
        }
    }
}
