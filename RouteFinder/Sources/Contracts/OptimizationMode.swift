/// Route optimization strategy applied by the cost model.
public enum OptimizationMode: String, Codable, Sendable, Hashable, CaseIterable {
    /// Minimize travel time.
    case fastest
    /// Minimize total distance.
    case shortest
    /// Minimize time with penalties for complex turns.
    case simplest
    /// Minimize time while avoiding stressful roads and cameras.
    case leastStressful
}
