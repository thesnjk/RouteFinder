/// H3-compatible spatial cell identifier at a fixed resolution.
public struct H3CellIndex: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Encoded cell value.
    public let value: UInt64

    public init(value: UInt64) {
        self.value = value
    }

    public var description: String {
        String(value, radix: 16)
    }
}

/// A serializable graph tile for one H3 cell.
public struct GraphTile: Encodable, Sendable {
    /// Optional schema version for forward-compatible tile exports.
    public let schemaVersion: Int?
    /// H3 cell this tile covers.
    public let h3Index: H3CellIndex
    /// Nodes in this tile.
    public let nodes: [Node]
    /// Edges in this tile.
    public let edges: [Edge]

    /// Creates a graph tile.
    public init(
        schemaVersion: Int? = 2,
        h3Index: H3CellIndex,
        nodes: [Node],
        edges: [Edge]
    ) {
        self.schemaVersion = schemaVersion
        self.h3Index = h3Index
        self.nodes = nodes
        self.edges = edges
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case h3Index
        case nodes, edges
    }
}

extension GraphTile: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        h3Index = try container.decode(H3CellIndex.self, forKey: .h3Index)
        nodes = try container.decodeIfPresent([Node].self, forKey: .nodes) ?? []
        edges = try container.decodeIfPresent([Edge].self, forKey: .edges) ?? []
    }
}
