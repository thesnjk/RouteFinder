/// A geographic vertex in the routing graph.
public struct Node: Sendable, Hashable, Codable, Identifiable {
    /// Unique identifier for this node.
    public let id: String
    /// Latitude in decimal degrees.
    public let latitude: Double
    /// Longitude in decimal degrees.
    public let longitude: Double
    /// Optional human-readable label.
    public let name: String?

    /// Creates a graph node at the given coordinates.
    public init(id: String, latitude: Double, longitude: Double, name: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }
}
