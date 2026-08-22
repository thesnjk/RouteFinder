import Foundation

/// Distance-based voice announcement tier for turn-by-turn guidance.
public enum AnnouncementTier: String, Sendable, Equatable, Codable, CaseIterable {
    /// Early warning at approximately one mile.
    case approach
    /// Preparation cue at approximately one quarter mile.
    case prepare
    /// Immediate execution cue at approximately 500 feet.
    case execute

    /// Distance threshold in meters for this tier.
    public var thresholdMeters: Double {
        switch self {
        case .approach: 1609
        case .prepare: 402
        case .execute: 152
        }
    }

    /// Speech priority; higher values may interrupt lower tiers.
    public var priority: Int {
        switch self {
        case .approach: 1
        case .prepare: 2
        case .execute: 3
        }
    }
}
