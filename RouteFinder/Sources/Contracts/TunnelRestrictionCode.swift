/// ADR tunnel restriction codes for hazmat cargo routing.
public enum TunnelRestrictionCode: String, Codable, Sendable, Hashable, CaseIterable {
    /// No tunnel restriction.
    case none
    /// Code B — most restrictive categories barred from B tunnels.
    case b
    /// Code C.
    case c
    /// Code D.
    case d
    /// Code E — least restrictive of the coded set.
    case e

    /// Human-readable label for UI pickers.
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        }
    }
}
