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

    /// Spoken prompt for a given tier and instruction.
    public static func spokenPrompt(
        for instruction: TurnInstruction,
        tier: AnnouncementTier
    ) -> String {
        let phrase = shortPhrase(for: instruction.maneuver)

        switch tier {
        case .approach:
            return "In one mile, \(phrase.lowercased())\(roadSuffix(for: instruction, tier: tier))"
        case .prepare:
            return "In a quarter mile, \(phrase.lowercased())"
        case .execute:
            if instruction.maneuver == .arrive {
                return phrase
            }
            if let laneText = instruction.laneGuidance?.guidanceText, !laneText.isEmpty {
                return "\(laneText). \(phrase)"
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
