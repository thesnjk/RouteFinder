import Foundation

/// Maneuver type for turn-by-turn navigation.
public enum TurnManeuver: String, Codable, Sendable, Hashable {
    case depart
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurn
    case roundabout
    case speedCamera
    case averageSpeedZone
    case arrive
}

/// A single turn-by-turn navigation instruction.
public struct TurnInstruction: Sendable, Hashable, Codable, Identifiable {
    /// Stable identifier for list rendering.
    public let id: UUID
    /// The maneuver to perform.
    public let maneuver: TurnManeuver
    /// Road name for this segment, if known.
    public let roadName: String?
    /// Distance covered by this instruction in meters.
    public let distance: Double
    /// Bearing in degrees (0–360) after the maneuver.
    public let bearing: Double
    /// Recommended cornering speed in km/h, when curve-speed enforcement is active.
    public let recommendedSpeedKmh: Double?
    /// Optional structured lane guidance for the upcoming junction.
    public let laneGuidance: LaneGuidance?

    /// Compact lane guidance text for legacy surfaces.
    public var laneGuidanceText: String? {
        laneGuidance?.guidanceText
    }

    /// Creates a turn instruction.
    public init(
        id: UUID = UUID(),
        maneuver: TurnManeuver,
        roadName: String?,
        distance: Double,
        bearing: Double,
        recommendedSpeedKmh: Double? = nil,
        laneGuidance: LaneGuidance? = nil
    ) {
        self.id = id
        self.maneuver = maneuver
        self.roadName = roadName
        self.distance = distance
        self.bearing = bearing
        self.recommendedSpeedKmh = recommendedSpeedKmh
        self.laneGuidance = laneGuidance
    }
}
