import Contracts
import Foundation

/// A graph assembled from multiple H3 tiles, conforming to GraphProtocol.
public final class TiledGraph: GraphProtocol, @unchecked Sendable {
    private var nodes: [String: Node]
    private var adjacency: [String: [Edge]]
    private var directedEdgeCount: Int
    private var spatialIndex: [SpatialCell: [String]]?

    /// Creates a tiled graph from loaded tiles.
    public init(tiles: [GraphTile]) {
        self.nodes = [:]
        self.adjacency = [:]
        self.directedEdgeCount = 0
        self.spatialIndex = nil

        for tile in tiles {
            for node in tile.nodes {
                nodes[node.id] = node
                if adjacency[node.id] == nil {
                    adjacency[node.id] = []
                }
            }
            for edge in tile.edges {
                adjacency[edge.from, default: []].append(edge)
                directedEdgeCount += 1
            }
        }

        buildSpatialIndex()
    }

    public var nodeCount: Int { nodes.count }
    public var edgeCount: Int { directedEdgeCount }

    /// All node IDs in the merged graph.
    public var allNodeIDs: [String] { Array(nodes.keys) }

    public func node(id: String) -> Node? {
        nodes[id]
    }

    public func neighbors(of nodeID: String) -> [Edge] {
        adjacency[nodeID] ?? []
    }

    public func edge(from: String, to: String) -> Edge? {
        adjacency[from]?.first { $0.to == to }
    }

    public func matchingNodeID(for identifier: String) -> String? {
        if nodes[identifier] != nil { return identifier }
        let suffix = ":\(identifier)"
        return nodes.keys.first { $0.hasSuffix(suffix) }
    }

    public func findNearestNode(to coordinate: Coordinate) -> Node? {
        if spatialIndex == nil { buildSpatialIndex() }
        guard let index = spatialIndex else { return nil }

        let cellSize = 0.01
        let centerCell = SpatialCell(latitude: coordinate.latitude, longitude: coordinate.longitude, cellSize: cellSize)

        var bestNode: Node?
        var bestDistance = Double.infinity

        for ring in 0...10 {
            for cell in centerCell.neighbors(at: ring) {
                guard let nodeIDs = index[cell] else { continue }
                for id in nodeIDs {
                    guard let node = nodes[id] else { continue }
                    let dist = haversineDistance(
                        lat1: coordinate.latitude, lon1: coordinate.longitude,
                        lat2: node.latitude, lon2: node.longitude
                    )
                    if dist < bestDistance {
                        bestDistance = dist
                        bestNode = node
                    }
                }
            }
            if bestNode != nil { break }
        }

        return bestNode
    }

    /// Returns road segments near a coordinate for map matching.
    public func roadSegments(near coordinate: Coordinate, radiusMeters: Double = 800) -> [RoadSegment] {
        if spatialIndex == nil { buildSpatialIndex() }
        guard let index = spatialIndex else { return [] }

        let cellSize = 0.01
        let centerCell = SpatialCell(latitude: coordinate.latitude, longitude: coordinate.longitude, cellSize: cellSize)
        var visitedNodes: Set<String> = []
        var segments: [RoadSegment] = []
        let maxRings = Int(ceil(radiusMeters / (cellSize * 111_000))) + 2

        for ring in 0...maxRings {
            for cell in centerCell.neighbors(at: ring) {
                guard let nodeIDs = index[cell] else { continue }
                for id in nodeIDs {
                    guard !visitedNodes.contains(id), let node = nodes[id] else { continue }
                    visitedNodes.insert(id)
                    let nodeCoord = Coordinate(latitude: node.latitude, longitude: node.longitude)
                    guard haversineDistance(
                        lat1: coordinate.latitude, lon1: coordinate.longitude,
                        lat2: node.latitude, lon2: node.longitude
                    ) <= radiusMeters * 1.5 else { continue }

                    for edge in neighbors(of: id) {
                        guard let toNode = nodes[edge.to] else { continue }
                        let toCoord = Coordinate(latitude: toNode.latitude, longitude: toNode.longitude)
                        segments.append(RoadSegment(edge: edge, from: nodeCoord, to: toCoord))
                    }
                }
            }
        }
        return segments
    }

    /// Snaps a coordinate to the nearest road segment using edge projection.
    public func matchToRoad(to coordinate: Coordinate, maxDistanceMeters: Double) -> MapMatchResult? {
        let segments = roadSegments(near: coordinate, radiusMeters: maxDistanceMeters * 1.5)
        if let match = MapMatcher.bestMatch(to: coordinate, segments: segments, maxDistanceMeters: maxDistanceMeters) {
            return match
        }
        guard let node = findNearestNode(to: coordinate) else { return nil }
        let snapped = Coordinate(latitude: node.latitude, longitude: node.longitude)
        let distance = haversineDistance(
            lat1: coordinate.latitude, lon1: coordinate.longitude,
            lat2: node.latitude, lon2: node.longitude
        )
        guard distance <= maxDistanceMeters else { return nil }
        return MapMatchResult(
            nodeID: node.id,
            snappedCoordinate: snapped,
            snapDistanceMeters: distance,
            roadName: node.name
        )
    }

    private func buildSpatialIndex() {
        var index: [SpatialCell: [String]] = [:]
        let cellSize = 0.01
        for (id, node) in nodes {
            let cell = SpatialCell(latitude: node.latitude, longitude: node.longitude, cellSize: cellSize)
            index[cell, default: []].append(id)
        }
        spatialIndex = index
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}

private struct SpatialCell: Hashable {
    let row: Int
    let col: Int

    init(latitude: Double, longitude: Double, cellSize: Double) {
        row = Int(floor(latitude / cellSize))
        col = Int(floor(longitude / cellSize))
    }

    func neighbors(at ring: Int) -> [SpatialCell] {
        var cells: [SpatialCell] = []
        for dr in -ring...ring {
            for dc in -ring...ring {
                if max(abs(dr), abs(dc)) == ring {
                    cells.append(SpatialCell(row: row + dr, col: col + dc))
                }
            }
        }
        return cells
    }

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}
