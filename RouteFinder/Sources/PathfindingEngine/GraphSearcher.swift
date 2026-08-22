import Contracts
import CostModel
import GraphCore
import Collections
import Foundation

/// Priority queue entry for graph search.
struct SearchEntry: Comparable {
    let nodeID: String
    let priority: Double

    static func < (lhs: SearchEntry, rhs: SearchEntry) -> Bool {
        lhs.priority < rhs.priority
    }
}

/// Shared graph search engine used by Dijkstra and A*.
enum GraphSearcher {
    static func search(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        preferences: RoutingPreferences,
        costModel: any CostModelProtocol,
        heuristic: ((String) -> Double)?
    ) -> (path: [String], nodesVisited: Int, cameFrom: [String: (String, Edge)], searchCost: Double)? {
        let prefs = preferences.preferenceProfile
        let vehicle = preferences.vehicle

        var openSet = Heap<SearchEntry>()
        var gScore: [String: Double] = [startID: 0]
        var cameFrom: [String: (String, Edge)] = [:]
        var closedSet: Set<String> = []
        var nodesVisited = 0

        let h0 = heuristic?(startID) ?? 0
        openSet.insert(SearchEntry(nodeID: startID, priority: h0))

        while let current = openSet.popMin()?.nodeID {
            if current == endID {
                let path = reconstructPath(cameFrom: cameFrom, current: endID)
                let searchCost = gScore[endID] ?? 0
                return (path, nodesVisited, cameFrom, searchCost)
            }

            if closedSet.contains(current) { continue }
            closedSet.insert(current)
            nodesVisited += 1

            let currentG = gScore[current] ?? .infinity
            var previousRoadType: RoadType?
            if let (_, prevEdge) = cameFrom[current] {
                previousRoadType = prevEdge.roadType
            }

            for edge in graph.neighbors(of: current) {
                guard costModel.isFeasible(edge: edge, vehicle: vehicle, prefs: prefs) else { continue }

                let edgeCost = costModel.computeCost(edge: edge, prefs: prefs, previousRoadType: previousRoadType)
                let tentativeG = currentG + edgeCost

                if tentativeG < (gScore[edge.to] ?? .infinity) {
                    gScore[edge.to] = tentativeG
                    cameFrom[edge.to] = (current, edge)
                    let h = heuristic?(edge.to) ?? 0
                    openSet.insert(SearchEntry(nodeID: edge.to, priority: tentativeG + h))
                }
            }
        }

        return nil
    }

    private static func reconstructPath(cameFrom: [String: (String, Edge)], current: String) -> [String] {
        var path = [current]
        var node = current
        while let (prev, _) = cameFrom[node] {
            path.append(prev)
            node = prev
        }
        return path.reversed()
    }
}
