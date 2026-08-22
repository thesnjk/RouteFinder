import Foundation

/// Coordinate pair safe to send to any routing engine. No address text.
public struct RoutingCoordinate: Sendable, Codable, Hashable {
    /// Latitude in decimal degrees.
    public let latitude: Double
    /// Longitude in decimal degrees.
    public let longitude: Double

    /// Creates a routing-safe coordinate.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Creates a routing coordinate from a generic geographic coordinate.
    public init(_ coordinate: Coordinate) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    /// Converts to the shared `Coordinate` type used by tile and graph layers.
    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}

extension Coordinate {
    /// Routing-safe view of this coordinate (no display metadata).
    public var routingCoordinate: RoutingCoordinate {
        RoutingCoordinate(latitude: latitude, longitude: longitude)
    }
}

extension GeocodeSuggestion {
    /// Extracts routing geometry immediately on geocoder selection; labels stay UI-only.
    public var routingCoordinate: RoutingCoordinate {
        coordinate.routingCoordinate
    }
}

extension ResolvedEndpoint {
    /// Prefers the raw geocode coordinate when unsnapped; otherwise uses the snapped road point.
    public var routingCoordinate: RoutingCoordinate {
        if nodeID == nil {
            return rawCoordinate.routingCoordinate
        }
        return snappedCoordinate.routingCoordinate
    }
}
