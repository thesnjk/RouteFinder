import Foundation

/// A waypoint with optional scheduling and capacity constraints for TSP optimization.
public struct OptimizationWaypoint: Codable, Equatable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this stop.
    public let id: UUID
    /// Geographic coordinate for routing.
    public let coordinate: RoutingCoordinate
    /// Optional service time window.
    public let timeWindow: TimeWindow?
    /// Optional delivery demand in arbitrary units (e.g. kg).
    public let demand: Int?

    /// Creates an optimization waypoint.
    public init(
        id: UUID = UUID(),
        coordinate: RoutingCoordinate,
        timeWindow: TimeWindow? = nil,
        demand: Int? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.timeWindow = timeWindow
        self.demand = demand
    }

    /// Creates an optimization waypoint from a routing coordinate only.
    public init(coordinate: RoutingCoordinate) {
        self.init(id: UUID(), coordinate: coordinate, timeWindow: nil, demand: nil)
    }
}
