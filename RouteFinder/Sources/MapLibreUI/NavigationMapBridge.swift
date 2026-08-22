import Contracts
import CoreLocation
import Foundation

/// Bridges navigation session updates to the MapLibre WKWebView coordinator.
@MainActor
public final class NavigationMapBridge {
    public static let shared = NavigationMapBridge()

    /// Optional handler registered by the map coordinator for per-tick vehicle pushes.
    public var pushVehicle: ((SimulatedVehicleState) -> Void)?
    /// Optional handler for route progress fraction updates during navigation.
    public var pushRouteProgress: ((RouteProgressState) -> Void)?
    /// Optional handler for explicit traveled/remaining polyline split updates.
    public var pushRouteSplit: ((RouteSplitResult) -> Void)?
    /// Optional handler to load route geometry with cumulative arc lengths.
    public var loadRouteGeometry: (([CLLocationCoordinate2D], [Double], Double) -> Void)?
    /// Optional handler to begin procedural route reveal animation.
    public var beginRouteReveal: (([CLLocationCoordinate2D], Double, [Double]) -> Void)?

    private init() {}

    /// Pushes the latest vehicle state to the map layer when a handler is registered.
    public func push(_ state: SimulatedVehicleState) {
        pushVehicle?(state)
    }

    /// Pushes route progress for traveled/remaining polyline highlighting.
    public func pushProgress(_ state: RouteProgressState) {
        pushRouteProgress?(state)
    }

    /// Pushes an explicit route split result for traveled/remaining layer styling.
    public func pushSplit(_ split: RouteSplitResult) {
        pushRouteSplit?(split)
    }

    /// Loads canonical route geometry into the map layer.
    public func loadRoute(
        coordinates: [CLLocationCoordinate2D],
        cumulativeLengths: [Double],
        totalLengthMeters: Double
    ) {
        loadRouteGeometry?(coordinates, cumulativeLengths, totalLengthMeters)
    }

    /// Begins procedural route reveal using display coordinates and cumulative arc lengths.
    public func revealRoute(
        coordinates: [CLLocationCoordinate2D],
        totalLengthMeters: Double,
        cumulativeLengths: [Double]
    ) {
        beginRouteReveal?(coordinates, totalLengthMeters, cumulativeLengths)
    }
}

/// Backward-compatible alias for simulation-era bridge references.
public typealias SimulationMapBridge = NavigationMapBridge
