import Contracts
import Foundation

/// Parses OSM `turn:lanes` / `lanes` tags into structured lane guidance.
public enum TurnLanesParser: Sendable {
    /// Parses a `turn:lanes` tag value such as `left|through|right`.
    public static func parse(turnLanes: String) -> LaneGuidance? {
        let tokens = turnLanes
            .split(separator: "|")
            .map { normalizeToken(String($0)) }
        guard !tokens.isEmpty else { return nil }

        let lanes = tokens.map { arrow(for: $0) }
        let recommended = tokens.enumerated().compactMap { index, token in
            isRecommended(token) ? index : nil
        }
        let indices = recommended.isEmpty ? defaultRecommendedIndices(for: lanes) : recommended
        return LaneGuidance(lanes: lanes, recommendedIndices: indices)
    }

    /// Builds heuristic lane guidance from a maneuver when OSM data is unavailable.
    public static func heuristic(for maneuver: TurnManeuver, laneCount: Int = 3) -> LaneGuidance {
        let lanes = (0..<max(laneCount, 1)).map { _ in LaneArrow.straight }
        let recommended: [Int]
        switch maneuver {
        case .slightLeft, .left, .sharpLeft:
            recommended = [0]
        case .slightRight, .right, .sharpRight:
            recommended = [lanes.count - 1]
        case .uTurn:
            recommended = [0]
        default:
            recommended = [lanes.count / 2]
        }
        var adjustedLanes = lanes
        for index in recommended {
            guard adjustedLanes.indices.contains(index) else { continue }
            adjustedLanes[index] = arrow(for: maneuver)
        }
        return LaneGuidance(lanes: adjustedLanes, recommendedIndices: recommended)
    }

    private static func normalizeToken(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "none", with: "")
            .replacingOccurrences(of: "merge_to_left", with: "merge")
            .replacingOccurrences(of: "merge_to_right", with: "merge")
    }

    private static func isRecommended(_ token: String) -> Bool {
        !token.isEmpty && token != "none"
    }

    private static func arrow(for token: String) -> LaneArrow {
        if token.contains("slight_left") || token == "slightleft" { return .slightLeft }
        if token.contains("sharp_left") || token == "sharpleft" { return .left }
        if token.contains("left") { return .left }
        if token.contains("slight_right") || token == "slightright" { return .slightRight }
        if token.contains("sharp_right") || token == "sharpright" { return .right }
        if token.contains("right") { return .right }
        if token.contains("through") || token.contains("straight") { return .straight }
        if token.contains("merge") { return .merge }
        return .unknown
    }

    private static func arrow(for maneuver: TurnManeuver) -> LaneArrow {
        switch maneuver {
        case .slightLeft: return .slightLeft
        case .left, .sharpLeft: return .left
        case .slightRight: return .slightRight
        case .right, .sharpRight: return .right
        case .uTurn: return .left
        default: return .straight
        }
    }

    private static func defaultRecommendedIndices(for lanes: [LaneArrow]) -> [Int] {
        if let straightIndex = lanes.firstIndex(where: { $0 == .straight }) {
            return [straightIndex]
        }
        return [lanes.count / 2]
    }
}
