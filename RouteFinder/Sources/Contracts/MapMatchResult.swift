import Foundation

/// Result of snapping a geographic coordinate to the road network.
public struct MapMatchResult: Sendable, Hashable {
    /// Graph node ID used as the routing endpoint.
    public let nodeID: String
    /// Coordinate after projection onto the nearest road segment.
    public let snappedCoordinate: Coordinate
    /// Distance from the raw click to the snapped point, in meters.
    public let snapDistanceMeters: Double
    /// Road name of the matched segment, if available.
    public let roadName: String?

    /// Creates a map-matching result.
    public init(
        nodeID: String,
        snappedCoordinate: Coordinate,
        snapDistanceMeters: Double,
        roadName: String? = nil
    ) {
        self.nodeID = nodeID
        self.snappedCoordinate = snappedCoordinate
        self.snapDistanceMeters = snapDistanceMeters
        self.roadName = roadName
    }
}

/// A geocoding suggestion from local OSM data or an external geocoder.
public struct GeocodeSuggestion: Identifiable, Sendable, Hashable, Encodable {
    /// Stable identifier for list rendering.
    public let id: String
    /// Primary label shown in search results.
    public let title: String
    /// Secondary context (locality, road type, etc.).
    public let subtitle: String
    /// Resolved geographic coordinate.
    public let coordinate: Coordinate
    /// Whether this suggestion came from the local OSM street index.
    public let isLocal: Bool

    /// Creates a geocoding suggestion.
    public init(
        id: String,
        title: String,
        subtitle: String,
        coordinate: Coordinate,
        isLocal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.isLocal = isLocal
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, coordinate, isLocal
    }
}

extension GeocodeSuggestion: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        coordinate = try container.decode(Coordinate.self, forKey: .coordinate)
        isLocal = (try? container.decode(Bool.self, forKey: .isLocal)) ?? false
    }
}

/// Resolved endpoint with both display and routing metadata.
public struct ResolvedEndpoint: Sendable, Hashable {
    /// Human-readable label shown in the input field.
    public var displayLabel: String
    /// Original coordinate from click or geocoder.
    public var rawCoordinate: Coordinate
    /// Snapped coordinate on the road network.
    public var snappedCoordinate: Coordinate
    /// Matched graph node ID for routing.
    public var nodeID: String?
    /// Snap distance in meters, if matched.
    public var snapDistanceMeters: Double?
    /// Road name at the snap point.
    public var roadName: String?

    /// Creates a resolved endpoint.
    public init(
        displayLabel: String,
        rawCoordinate: Coordinate,
        snappedCoordinate: Coordinate,
        nodeID: String? = nil,
        snapDistanceMeters: Double? = nil,
        roadName: String? = nil
    ) {
        self.displayLabel = displayLabel
        self.rawCoordinate = rawCoordinate
        self.snappedCoordinate = snappedCoordinate
        self.nodeID = nodeID
        self.snapDistanceMeters = snapDistanceMeters
        self.roadName = roadName
    }

    /// Routing-safe coordinate locked at selection (prefers raw geocode when unsnapped).
    public var waypoint: Waypoint {
        if nodeID == nil {
            return Waypoint(
                latitude: rawCoordinate.latitude,
                longitude: rawCoordinate.longitude
            )
        }
        return Waypoint(
            latitude: snappedCoordinate.latitude,
            longitude: snappedCoordinate.longitude
        )
    }
}
