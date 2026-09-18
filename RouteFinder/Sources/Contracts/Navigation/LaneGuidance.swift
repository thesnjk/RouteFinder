import Foundation

/// Lane arrow direction for junction guidance strips.
public enum LaneArrow: String, Codable, Sendable, Hashable, CaseIterable {
    case straight
    case slightLeft
    case left
    case slightRight
    case right
    case merge
    case unknown
}

/// Structured lane guidance for a maneuver.
public struct LaneGuidance: Sendable, Hashable, Codable, Equatable {
    /// Lanes ordered left-to-right at the junction.
    public let lanes: [LaneArrow]
    /// Indices into ``lanes`` that the driver should use.
    public let recommendedIndices: [Int]
    /// Whether guidance came from OSM tags or a heuristic estimate.
    public let source: LaneGuidanceSource

    /// Creates lane guidance.
    public init(
        lanes: [LaneArrow],
        recommendedIndices: [Int],
        source: LaneGuidanceSource = .unknown
    ) {
        self.lanes = lanes
        self.recommendedIndices = recommendedIndices
        self.source = source
    }

    /// Human-readable guidance for voice and compact labels.
    public var guidanceText: String {
        guard !lanes.isEmpty else { return "Follow road" }
        if recommendedIndices.count == 1, let index = recommendedIndices.first {
            let laneNumber = index + 1
            let direction = lanes[index]
            switch direction {
            case .left, .slightLeft:
                return laneNumber == 1 ? "Use the left lane" : "Use lane \(laneNumber)"
            case .right, .slightRight:
                return laneNumber == lanes.count ? "Use the right lane" : "Use lane \(laneNumber)"
            case .merge:
                return "Merge"
            default:
                return laneNumber == 1 ? "Keep left" : (laneNumber == lanes.count ? "Keep right" : "Use lane \(laneNumber)")
            }
        }
        if recommendedIndices.count > 1 {
            let numbers = recommendedIndices.map { String($0 + 1) }.joined(separator: " and ")
            return "Use lanes \(numbers)"
        }
        return "Follow road"
    }
}
