import Contracts
import Foundation

/// Finds the nearest connected node when the resolved node has no neighbors.
public enum ConnectedNodeFinder {
    /// Expands outward via BFS until a node with at least one neighbor is found.
    public static func findNearestConnectedNode(
        startingFrom nodeID: String,
        graph: any GraphProtocol,
        maxHops: Int = 20
    ) -> String? {
        if !graph.neighbors(of: nodeID).isEmpty {
            return nodeID
        }

        var visited: Set<String> = [nodeID]
        var frontier: [String] = [nodeID]

        for _ in 0..<maxHops {
            var nextFrontier: [String] = []
            for current in frontier {
                for edge in graph.neighbors(of: current) {
                    if visited.contains(edge.to) { continue }
                    visited.insert(edge.to)
                    if !graph.neighbors(of: edge.to).isEmpty {
                        return edge.to
                    }
                    nextFrontier.append(edge.to)
                }
            }
            frontier = nextFrontier
            if frontier.isEmpty { break }
        }

        return nil
    }
}
