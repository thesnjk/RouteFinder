import Foundation

/// A highway layby / rest pull-off projected onto the active route.
public struct LaybyStop: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let coordinate: Coordinate
    public let label: String
    public let arcLengthAlongRouteMeters: Double?
    public let distanceFromRouteMeters: Double?

    /// Creates a layby stop.
    public init(
        id: String,
        coordinate: Coordinate,
        label: String,
        arcLengthAlongRouteMeters: Double? = nil,
        distanceFromRouteMeters: Double? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.label = label
        self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
        self.distanceFromRouteMeters = distanceFromRouteMeters
    }
}

/// Upcoming layby advisory for the driver HUD.
public struct LaybyAdvisory: Sendable, Hashable, Codable, Equatable {
    public let stop: LaybyStop
    public let distanceRemainingMeters: Double
    public let estimatedArrivalSeconds: TimeInterval?

    /// Creates a layby advisory.
    public init(
        stop: LaybyStop,
        distanceRemainingMeters: Double,
        estimatedArrivalSeconds: TimeInterval? = nil
    ) {
        self.stop = stop
        self.distanceRemainingMeters = distanceRemainingMeters
        self.estimatedArrivalSeconds = estimatedArrivalSeconds
    }
}
