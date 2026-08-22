import Contracts
import Foundation

/// Adjacency-list graph backed by cache-friendly contiguous edge arrays.
public final class Graph: GraphProtocol, @unchecked Sendable {
    private var nodes: [String: Node]
    private var adjacency: [String: ContiguousArray<Edge>]
    private var directedEdgeCount: Int
    private var spatialIndex: [SpatialCell: [String]]?

    /// Creates an empty graph.
    public init() {
        self.nodes = [:]
        self.adjacency = [:]
        self.directedEdgeCount = 0
        self.spatialIndex = nil
    }

    /// Creates a graph with pre-reserved capacity.
    public init(nodeCapacity: Int, edgeCapacity: Int) {
        self.nodes = [:]
        self.nodes.reserveCapacity(nodeCapacity)
        self.adjacency = [:]
        self.adjacency.reserveCapacity(nodeCapacity)
        self.directedEdgeCount = 0
        self.spatialIndex = nil
        _ = edgeCapacity
    }

    public var nodeCount: Int { nodes.count }
    public var edgeCount: Int { directedEdgeCount }

    public func node(id: String) -> Node? {
        nodes[id]
    }

    public func neighbors(of nodeID: String) -> [Edge] {
        guard let edges = adjacency[nodeID] else { return [] }
        return Array(edges)
    }

    /// All node IDs in the graph.
    public var nodeIDs: [String] {
        Array(nodes.keys)
    }

    /// Finds an edge between two nodes.
    public func edge(from: String, to: String) -> Edge? {
        adjacency[from]?.first { $0.to == to }
    }
}

// MARK: - Mutation

extension Graph {
    /// Adds a node to the graph, replacing any existing node with the same ID.
    @discardableResult
    public func addNode(_ node: Node) -> Graph {
        nodes[node.id] = node
        if adjacency[node.id] == nil {
            adjacency[node.id] = ContiguousArray()
        }
        spatialIndex = nil
        return self
    }

    /// Adds a directed edge; creates reverse edge unless one-way.
    @discardableResult
    public func addEdge(_ edge: Edge) -> Graph {
        if adjacency[edge.from] == nil {
            adjacency[edge.from] = ContiguousArray()
        }
        if adjacency[edge.to] == nil {
            adjacency[edge.to] = ContiguousArray()
        }

        adjacency[edge.from, default: ContiguousArray()].append(edge)
        directedEdgeCount += 1

        if !edge.isOneWay {
            let reverse = Edge(
                from: edge.to,
                to: edge.from,
                distance: edge.distance,
                speed: edge.speed,
                roadType: edge.roadType,
                isToll: edge.isToll,
                isFerry: edge.isFerry,
                isTunnel: edge.isTunnel,
                maxHeight: edge.maxHeight,
                maxWeight: edge.maxWeight,
                maxWidth: edge.maxWidth,
                maxLength: edge.maxLength,
                hasCamera: edge.hasCamera,
                cameraType: edge.cameraType,
                isOneWay: false,
                hgvRestricted: edge.hgvRestricted,
                maxAxleWeight: edge.maxAxleWeight,
                hazmatRestricted: edge.hazmatRestricted,
                lezRestricted: edge.lezRestricted,
                minTurnRadius: edge.minTurnRadius,
                roadName: edge.roadName
            )
            adjacency[edge.to, default: ContiguousArray()].append(reverse)
            directedEdgeCount += 1
        }

        return self
    }
}

// MARK: - Spatial

extension Graph {
    /// Grid cell size in degrees (~1.1 km at equator).
    private static let gridCellSize: Double = 0.01

    /// Builds or rebuilds the spatial index for fast nearest-node lookup.
    public func buildSpatialIndex() {
        var index: [SpatialCell: [String]] = [:]
        index.reserveCapacity(nodes.count / 4)
        for (id, node) in nodes {
            let cell = SpatialCell(latitude: node.latitude, longitude: node.longitude, cellSize: Self.gridCellSize)
            index[cell, default: []].append(id)
        }
        spatialIndex = index
    }

    public func findNearestNode(to coordinate: Coordinate) -> Node? {
        if spatialIndex == nil && !nodes.isEmpty {
            buildSpatialIndex()
        }

        guard let index = spatialIndex else { return nil }

        let centerCell = SpatialCell(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cellSize: Self.gridCellSize
        )

        var bestNode: Node?
        var bestDistance = Double.infinity

        for ring in 0...10 {
            for cell in centerCell.neighbors(at: ring) {
                guard let nodeIDs = index[cell] else { continue }
                for id in nodeIDs {
                    guard let node = nodes[id] else { continue }
                    let dist = Haversine.distance(from: coordinate, to: Coordinate(latitude: node.latitude, longitude: node.longitude))
                    if dist < bestDistance {
                        bestDistance = dist
                        bestNode = node
                    }
                }
            }
            if bestNode != nil { break }
        }

        if bestNode == nil {
            for node in nodes.values {
                let dist = Haversine.distance(from: coordinate, to: Coordinate(latitude: node.latitude, longitude: node.longitude))
                if dist < bestDistance {
                    bestDistance = dist
                    bestNode = node
                }
            }
        }

        return bestNode
    }

    /// Returns road segments near a coordinate for map matching.
    public func roadSegments(near coordinate: Coordinate, radiusMeters: Double = 800) -> [RoadSegment] {
        if spatialIndex == nil && !nodes.isEmpty {
            buildSpatialIndex()
        }
        guard let index = spatialIndex else { return [] }

        let centerCell = SpatialCell(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cellSize: Self.gridCellSize
        )

        var visitedNodes: Set<String> = []
        var segments: [RoadSegment] = []
        let maxRings = Int(ceil(radiusMeters / (Self.gridCellSize * 111_000))) + 2

        for ring in 0...maxRings {
            for cell in centerCell.neighbors(at: ring) {
                guard let nodeIDs = index[cell] else { continue }
                for id in nodeIDs {
                    guard !visitedNodes.contains(id), let node = nodes[id] else { continue }
                    visitedNodes.insert(id)
                    let nodeCoord = Coordinate(latitude: node.latitude, longitude: node.longitude)
                    guard Haversine.distance(from: coordinate, to: nodeCoord) <= radiusMeters * 1.5 else { continue }

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
        let distance = Haversine.distance(from: coordinate, to: snapped)
        guard distance <= maxDistanceMeters else { return nil }
        return MapMatchResult(
            nodeID: node.id,
            snappedCoordinate: snapped,
            snapDistanceMeters: distance,
            roadName: node.name
        )
    }
}

// MARK: - Spatial Index Helpers

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
