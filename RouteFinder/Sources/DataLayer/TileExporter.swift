import Contracts
import GraphCore
import Foundation

/// Exports a graph into H3-indexed tile files.
public enum TileExporter {
    /// Exports a graph to JSON tile files in the given directory.
    public static func exportGraph(_ graph: Graph, to directory: URL, resolution: Int = H3Grid.defaultResolution) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var tiles: [H3CellIndex: (nodes: [Node], edges: [Edge])] = [:]

        for nodeID in graph.nodeIDs {
            guard let node = graph.node(id: nodeID) else { continue }
            let cell = H3Grid.cell(for: Coordinate(latitude: node.latitude, longitude: node.longitude), resolution: resolution)
            let globalID = "\(cell.description):\(nodeID)"
            let globalNode = Node(id: globalID, latitude: node.latitude, longitude: node.longitude, name: node.name)
            var bucket = tiles[cell] ?? (nodes: [], edges: [])
            bucket.nodes.append(globalNode)
            tiles[cell] = bucket
        }

        for nodeID in graph.nodeIDs {
            for edge in graph.neighbors(of: nodeID) {
                guard let fromNode = graph.node(id: nodeID) else { continue }
                let cell = H3Grid.cell(for: Coordinate(latitude: fromNode.latitude, longitude: fromNode.longitude), resolution: resolution)
                let globalFrom = "\(cell.description):\(edge.from)"
                let globalTo: String
                if let toNode = graph.node(id: edge.to) {
                    let toCell = H3Grid.cell(for: Coordinate(latitude: toNode.latitude, longitude: toNode.longitude), resolution: resolution)
                    globalTo = "\(toCell.description):\(edge.to)"
                } else {
                    globalTo = edge.to
                }
                let globalEdge = Edge(
                    from: globalFrom,
                    to: globalTo,
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
                    isOneWay: edge.isOneWay,
                    hgvRestricted: edge.hgvRestricted,
                    maxAxleWeight: edge.maxAxleWeight,
                    hazmatRestricted: edge.hazmatRestricted,
                    lezRestricted: edge.lezRestricted,
                    minTurnRadius: edge.minTurnRadius,
                    roadName: edge.roadName
                )
                var bucket = tiles[cell] ?? (nodes: [], edges: [])
                bucket.edges.append(globalEdge)
                tiles[cell] = bucket
            }
        }

        let index = H3TileIndex(tilesDirectory: directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for (cell, content) in tiles {
            let tile = GraphTile(h3Index: cell, nodes: content.nodes, edges: content.edges)
            let data = try encoder.encode(tile)
            try data.write(to: index.tileURL(for: cell))
        }
    }
}
