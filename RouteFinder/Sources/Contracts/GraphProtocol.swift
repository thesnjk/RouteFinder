import Foundation

/// A geographic coordinate used for spatial queries.
public struct Coordinate: Sendable, Hashable, Codable {
    /// Latitude in decimal degrees.
    public let latitude: Double
    /// Longitude in decimal degrees.
    public let longitude: Double
    /// Elevation in meters above sea level, when available from routing geometry.
    public let elevationMeters: Double?

    /// Creates a coordinate from latitude and longitude.
    public init(latitude: Double, longitude: Double, elevationMeters: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
    }
}

/// Abstract interface for a routing graph.
public protocol GraphProtocol: Sendable {
    /// Number of nodes in the graph.
    var nodeCount: Int { get }
    /// Number of directed edges in the graph.
    var edgeCount: Int { get }

    /// Returns the node with the given identifier, if it exists.
    func node(id: String) -> Node?

    /// Returns all outgoing edges from the given node.
    func neighbors(of nodeID: String) -> [Edge]

    /// Finds the nearest node to the given coordinate.
    func findNearestNode(to coordinate: Coordinate) -> Node?

    /// Finds an edge between two nodes, if it exists.
    func edge(from: String, to: String) -> Edge?

    /// Snaps a coordinate to the nearest drivable road segment within the given distance.
    func matchToRoad(to coordinate: Coordinate, maxDistanceMeters: Double) -> MapMatchResult?

    /// Resolves a user-provided identifier to a graph node ID.
    func matchingNodeID(for identifier: String) -> String?
}

extension GraphProtocol {
    /// Default exact-match node resolution.
    public func matchingNodeID(for identifier: String) -> String? {
        node(id: identifier) != nil ? identifier : nil
    }

    /// Default edge lookup returns nil when not implemented.
    public func edge(from: String, to: String) -> Edge? { nil }
}
