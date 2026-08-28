import Contracts
import Foundation

/// Parses OSM `turn:lanes` / `lanes` tags into structured lane guidance.
public enum TurnLanesParser: Sendable {
    /// Parses a `turn:lanes` tag value such as `left|through|right`.
    public static func parse(turnLanes: String) -> LaneGuidance? {
        parse(turnLanes: turnLanes, forManeuver: nil)
    }

    /// Parses a `turn:lanes` tag with optional maneuver-aware lane recommendations.
    public static func parse(turnLanes: String, forManeuver: TurnManeuver?) -> LaneGuidance? {
        let laneTokens = turnLanes.split(separator: "|").map(String.init)
        guard !laneTokens.isEmpty else { return nil }

        var lanes: [LaneArrow] = []
        var recommended: [Int] = []
        lanes.reserveCapacity(laneTokens.count)
        recommended.reserveCapacity(laneTokens.count)

        for (index, laneToken) in laneTokens.enumerated() {
            let subTokens = compoundSubTokens(from: laneToken)
            guard !subTokens.isEmpty else {
                lanes.append(.unknown)
                continue
            }

            let displayToken = displaySubToken(from: subTokens, forManeuver: forManeuver)
            lanes.append(arrow(for: displayToken))

            if let forManeuver {
                if subTokens.contains(where: { subTokenMatchesManeuver($0, maneuver: forManeuver) }) {
                    recommended.append(index)
                }
            } else if subTokens.contains(where: { isRecommended($0) }) {
                recommended.append(index)
            }
        }

        let indices: [Int]
        if let forManeuver {
            indices = recommended.isEmpty ? defaultRecommendedIndices(for: lanes, maneuver: forManeuver) : recommended
        } else {
            indices = recommended.isEmpty ? defaultRecommendedIndices(for: lanes, maneuver: nil) : recommended
        }

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

    private static func compoundSubTokens(from laneToken: String) -> [String] {
        laneToken
            .split(separator: ";")
            .map { normalizeSubToken(String($0)) }
            .filter { isRecommended($0) }
    }

    private static func normalizeSubToken(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "merge_to_left", with: "merge")
            .replacingOccurrences(of: "merge_to_right", with: "merge")
    }

    private static func displaySubToken(from subTokens: [String], forManeuver: TurnManeuver?) -> String {
        guard let forManeuver else {
            return subTokens.first ?? ""
        }
        if let matched = subTokens.first(where: { subTokenMatchesManeuver($0, maneuver: forManeuver) }) {
            return matched
        }
        return subTokens.first ?? ""
    }

    private static func isRecommended(_ token: String) -> Bool {
        !token.isEmpty && token != "none"
    }

    private static func subTokenMatchesManeuver(_ token: String, maneuver: TurnManeuver) -> Bool {
        let arrow = arrow(for: token)
        switch maneuver {
        case .slightLeft:
            return arrow == .slightLeft || arrow == .left
        case .left, .sharpLeft, .uTurn:
            return arrow == .left || arrow == .slightLeft
        case .slightRight:
            return arrow == .slightRight || arrow == .right
        case .right, .sharpRight:
            return arrow == .right || arrow == .slightRight
        case .straight, .roundabout, .depart:
            return arrow == .straight || arrow == .merge
        case .arrive, .speedCamera, .averageSpeedZone:
            return false
        }
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

    private static func defaultRecommendedIndices(for lanes: [LaneArrow], maneuver: TurnManeuver?) -> [Int] {
        if let maneuver {
            if let index = lanes.firstIndex(where: { arrowMatchesManeuver($0, maneuver: maneuver) }) {
                return [index]
            }
        }
        if let straightIndex = lanes.firstIndex(where: { $0 == .straight }) {
            return [straightIndex]
        }
        return [lanes.count / 2]
    }

    private static func arrowMatchesManeuver(_ arrow: LaneArrow, maneuver: TurnManeuver) -> Bool {
        subTokenMatchesManeuver(token(for: arrow), maneuver: maneuver)
    }

    private static func token(for arrow: LaneArrow) -> String {
        switch arrow {
        case .straight: "through"
        case .slightLeft: "slight_left"
        case .left: "left"
        case .slightRight: "slight_right"
        case .right: "right"
        case .merge: "merge"
        case .unknown: ""
        }
    }
}
