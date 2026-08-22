/// Strategy for computing edge costs and checking vehicle feasibility.
public protocol CostModelProtocol: Sendable {
    /// Returns whether a vehicle can traverse the given edge.
    func isFeasible(edge: Edge, vehicle: VehicleProfile, prefs: PreferenceProfile) -> Bool

    /// Computes the traversal cost for an edge given user preferences.
    func computeCost(edge: Edge, prefs: PreferenceProfile) -> Double

    /// Computes the traversal cost when entering from a previous road type (for turn penalties).
    func computeCost(edge: Edge, prefs: PreferenceProfile, previousRoadType: RoadType?) -> Double
}

extension CostModelProtocol {
    /// Returns whether a vehicle can traverse the given edge with default preferences.
    public func isFeasible(edge: Edge, vehicle: VehicleProfile) -> Bool {
        isFeasible(edge: edge, vehicle: vehicle, prefs: .default)
    }

    /// Default implementation without turn context.
    public func computeCost(edge: Edge, prefs: PreferenceProfile, previousRoadType: RoadType?) -> Double {
        computeCost(edge: edge, prefs: prefs)
    }
}
