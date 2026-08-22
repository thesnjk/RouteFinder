import Contracts
import GraphCore
import Foundation

/// Generates synthetic graphs for testing and demo purposes.
public enum SyntheticGraphBuilder {
    /// Creates a grid graph with predictable connectivity.
    ///
    /// Nodes are arranged in a `rows × cols` grid centered around (52.6, 1.3).
    public static func makeGrid(rows: Int, cols: Int, spacingMeters: Double = 500) -> Graph {
        let graph = Graph(nodeCapacity: rows * cols, edgeCapacity: rows * cols * 4)
        let originLat = 52.6
        let originLon = 1.3
        let latStep = spacingMeters / 111_000
        let lonStep = spacingMeters / (111_000 * cos(originLat * .pi / 180))

        for row in 0..<rows {
            for col in 0..<cols {
                let id = "N_\(row)_\(col)"
                let lat = originLat + Double(row) * latStep
                let lon = originLon + Double(col) * lonStep
                graph.addNode(Node(id: id, latitude: lat, longitude: lon, name: id))
            }
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let fromID = "N_\(row)_\(col)"
                if col + 1 < cols {
                    let toID = "N_\(row)_\(col + 1)"
                    addBidirectionalEdge(graph: graph, from: fromID, to: toID)
                }
                if row + 1 < rows {
                    let toID = "N_\(row + 1)_\(col)"
                    addBidirectionalEdge(graph: graph, from: fromID, to: toID)
                }
            }
        }

        graph.buildSpatialIndex()
        return graph
    }

    /// Creates a random connected graph with approximately `nodeCount` nodes.
    public static func makeRandom(nodeCount: Int, avgDegree: Int = 3, seed: UInt64 = 42) -> Graph {
        var rng = SeededRNG(seed: seed)
        let side = Int(ceil(sqrt(Double(nodeCount))))
        let graph = makeGrid(rows: side, cols: side)

        let extraEdges = nodeCount * avgDegree / 2
        let ids = graph.nodeIDs
        for _ in 0..<extraEdges {
            let from = ids[rng.next() % ids.count]
            let to = ids[rng.next() % ids.count]
            if from != to && graph.edge(from: from, to: to) == nil {
                addBidirectionalEdge(graph: graph, from: from, to: to)
            }
        }

        return graph
    }

    private static func addBidirectionalEdge(graph: Graph, from: String, to: String) {
        guard let fromNode = graph.node(id: from), let toNode = graph.node(id: to) else { return }
        let distance = Haversine.distance(from: fromNode, to: toNode)
        let edge = Edge(from: from, to: to, distance: distance, speed: 50, roadType: .residential, roadName: "\(from)-\(to)")
        graph.addEdge(edge)
    }
}

/// Simple seeded pseudo-random number generator for reproducible graphs.
struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> Int {
        state = state &* 6364136223846793005 &+ 1
        return Int(state >> 33)
    }
}
