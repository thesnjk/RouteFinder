import Foundation

/// Routing-safe coordinate locked at geocoder selection time.
///
/// Display labels live on ``ResolvedEndpoint/displayLabel`` and ``RouteWaypoint/rawText`` only;
/// routing must use ``routingCoordinate`` or ``coordinate``.
public struct Waypoint: Sendable, Hashable, Codable {
    /// Latitude in decimal degrees.
    public let latitude: Double
    /// Longitude in decimal degrees.
    public let longitude: Double

    /// Creates a waypoint from Nominatim lat/lon values only.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Creates a waypoint from a geocode suggestion coordinate.
    public init(_ suggestion: GeocodeSuggestion) {
        self.latitude = suggestion.coordinate.latitude
        self.longitude = suggestion.coordinate.longitude
    }

    /// Coordinate pair safe to send to any routing engine.
    public var routingCoordinate: RoutingCoordinate {
        RoutingCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Geographic coordinate for map display and tile layers.
    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}
