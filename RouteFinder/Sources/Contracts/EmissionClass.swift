/// European emission standard for low-emission zone compatibility.
public enum EmissionClass: String, Codable, Sendable, Hashable, CaseIterable {
    case euro1
    case euro2
    case euro3
    case euro4
    case euro5
    case euro6

    /// Numeric rank for compliance comparisons (higher = cleaner).
    public var euroRank: Int {
        switch self {
        case .euro1: return 1
        case .euro2: return 2
        case .euro3: return 3
        case .euro4: return 4
        case .euro5: return 5
        case .euro6: return 6
        }
    }
}
