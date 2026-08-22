/// Pathfinding algorithm selected in the UI.
public enum RoutingAlgorithm: String, Codable, Sendable, Hashable, CaseIterable {
    case aStar
    case dijkstra
}
