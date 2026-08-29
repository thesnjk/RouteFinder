import Foundation

/// Shared spoken and display labels for turn-by-turn maneuvers.
public enum ManeuverSpeechFormatter {
    /// Short maneuver phrase without road name, suitable for voice prompts.
    public static func shortPhrase(for maneuver: TurnManeuver) -> String {
        switch maneuver {
        case .depart: "Depart"
        case .straight: "Continue straight"
        case .slightLeft: "Slight left"
        case .left: "Turn left"
        case .sharpLeft: "Sharp left"
        case .slightRight: "Slight right"
        case .right: "Turn right"
        case .sharpRight: "Sharp right"
        case .uTurn: "Make a U-turn"
        case .roundabout: "Enter the roundabout"
        case .speedCamera: "Speed camera ahead"
        case .averageSpeedZone: "Average speed zone ahead"
        case .arrive: "You have arrived"
        }
    }

    /// Full maneuver description including road name for display surfaces.
    public static func displayDescription(for maneuver: TurnManeuver, roadName: String) -> String {
        switch maneuver {
        case .depart: "Depart onto \(roadName)"
        case .straight: "Continue on \(roadName)"
        case .slightLeft: "Slight left onto \(roadName)"
        case .left: "Turn left onto \(roadName)"
        case .sharpLeft: "Sharp left onto \(roadName)"
        case .slightRight: "Slight right onto \(roadName)"
        case .right: "Turn right onto \(roadName)"
        case .sharpRight: "Sharp right onto \(roadName)"
        case .uTurn: "Make a U-turn onto \(roadName)"
        case .roundabout: "Take the roundabout onto \(roadName)"
        case .speedCamera: "Speed camera on \(roadName)"
        case .averageSpeedZone: "Average speed zone on \(roadName)"
        case .arrive: "Arrive at destination"
        }
    }

    /// Spoken lane phrase for voice guidance (natural multi-lane wording).
    public static func spokenLanePhrase(for guidance: LaneGuidance) -> String {
        guard !guidance.lanes.isEmpty else { return "Follow the road" }
        let indices = guidance.recommendedIndices.sorted()
        guard !indices.isEmpty else { return "Follow the road" }

        if indices.count == 1, let index = indices.first {
            let laneCount = guidance.lanes.count
            switch guidance.lanes[index] {
            case .left, .slightLeft:
                return index == 0 ? "Use the left lane" : "Use lane \(index + 1)"
            case .right, .slightRight:
                return index == laneCount - 1 ? "Use the right lane" : "Use lane \(index + 1)"
            case .merge:
                return "Merge"
            default:
                if index == 0 { return "Keep left" }
                if index == laneCount - 1 { return "Keep right" }
                return "Use lane \(index + 1)"
            }
        }

        if indices.count > 1 {
            let laneCount = guidance.lanes.count
            let isContiguousFromLeft = indices == Array(0..<indices.count)
            let isContiguousFromRight = indices == Array((laneCount - indices.count)..<laneCount)
            if isContiguousFromLeft {
                return indices.count == 2 ? "Use the left two lanes" : "Use the left \(indices.count) lanes"
            }
            if isContiguousFromRight {
                return indices.count == 2 ? "Use the right two lanes" : "Use the right \(indices.count) lanes"
            }
            let numbers = indices.map { String($0 + 1) }.joined(separator: " and ")
            return "Use lanes \(numbers)"
        }

        return guidance.guidanceText
    }

    /// Spoken prompt for a given tier and instruction.
    public static func spokenPrompt(
        for instruction: TurnInstruction,
        tier: AnnouncementTier
    ) -> String {
        let phrase = shortPhrase(for: instruction.maneuver)

        switch tier {
        case .approach:
            if let laneText = instruction.laneGuidance.map({ spokenLanePhrase(for: $0) }), !laneText.isEmpty {
                return "In 1.6 kilometres, \(laneText.lowercased())\(roadSuffix(for: instruction, tier: tier))"
            }
            return "In 1.6 kilometres, \(phrase.lowercased())\(roadSuffix(for: instruction, tier: tier))"
        case .prepare:
            if let laneText = instruction.laneGuidance.map({ spokenLanePhrase(for: $0) }), !laneText.isEmpty {
                return "In 400 metres, \(laneText.lowercased())"
            }
            return "In 400 metres, \(phrase.lowercased())"
        case .execute:
            if instruction.maneuver == .arrive {
                return phrase
            }
            if let laneText = instruction.laneGuidance.map({ spokenLanePhrase(for: $0) }), !laneText.isEmpty {
                return "\(laneText), then \(phrase.lowercased())"
            }
            if let roadName = instruction.roadName, !roadName.isEmpty {
                return "\(phrase) onto \(roadName)"
            }
            return phrase
        }
    }

    /// Whether voice should be suppressed for the given maneuver at the given tier.
    public static func shouldSuppressVoice(
        maneuver: TurnManeuver,
        tier: AnnouncementTier
    ) -> Bool {
        switch maneuver {
        case .straight, .depart:
            return true
        case .speedCamera:
            return tier != .execute
        default:
            return false
        }
    }

    private static func roadSuffix(for instruction: TurnInstruction, tier: AnnouncementTier) -> String {
        guard tier == .approach,
              instruction.maneuver != .arrive,
              let road = instruction.roadName,
              !road.isEmpty else { return "" }
        return " onto \(road)"
    }
}
