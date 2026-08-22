/// A pathfinding algorithm that searches a graph for a route.
public protocol PathfindingAlgorithm: Sendable {
    /// Human-readable name of the algorithm.
    var name: String { get }

    /// Finds a route between two nodes using unified routing preferences.
    func findRoute(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        preferences: RoutingPreferences
    ) async -> SearchResult
}

extension PathfindingAlgorithm {
    /// Finds a route using separate vehicle and preference profiles (legacy API).
    public func findRoute(
        graph: any GraphProtocol,
        from startID: String,
        to endID: String,
        vehicle: VehicleProfile,
        prefs: PreferenceProfile
    ) async -> SearchResult {
        await findRoute(
            graph: graph,
            from: startID,
            to: endID,
            preferences: RoutingPreferences(
                optimizationMode: prefs.optimizationMode,
                avoidTolls: prefs.avoidTolls,
                avoidFerries: prefs.avoidFerries,
                avoidTunnels: prefs.avoidTunnels,
                hurryMode: prefs.hurryMode,
                vehicle: vehicle
            )
        )
    }
}
