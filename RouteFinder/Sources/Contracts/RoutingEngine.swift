/// External routing engine selection.
public enum RoutingEngine: String, Codable, Sendable, CaseIterable {
    /// HeiGIT OpenRouteService cloud routing with native HGV profile.
    case openRouteService
    /// Valhalla open-source routing engine (legacy; no longer used).
    case valhalla
    /// OSRM routing engine (reserved for future adapter).
    case osrm
    /// GraphHopper routing engine (reserved for future adapter).
    case graphhopper

    /// Human-readable label for UI pickers.
    public var displayName: String {
        switch self {
        case .openRouteService: return "OpenRouteService / HeiGIT"
        case .valhalla: return "Valhalla"
        case .osrm: return "OSRM"
        case .graphhopper: return "GraphHopper"
        }
    }

    /// Whether this engine is implemented and selectable.
    public var isAvailable: Bool {
        switch self {
        case .openRouteService: return true
        case .valhalla, .osrm, .graphhopper: return false
        }
    }

    /// Default routing engine for new sessions.
    public static let defaultEngine: RoutingEngine = .openRouteService
}
