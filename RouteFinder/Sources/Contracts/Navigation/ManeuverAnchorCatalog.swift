import Foundation

/// Anchor point for a turn instruction along the route spine.
public struct ManeuverAnchor: Sendable, Equatable, Identifiable {
    /// Stable identifier matching the turn instruction.
    public let id: UUID
    /// Arc length along the route spine in meters where the maneuver occurs.
    public let arcLengthAnchor: Double
    /// Road name associated with the maneuver.
    public let roadName: String?
    /// Maneuver type at this anchor.
    public let maneuver: TurnManeuver

    /// Creates a maneuver anchor.
    public init(
        id: UUID,
        arcLengthAnchor: Double,
        roadName: String?,
        maneuver: TurnManeuver
    ) {
        self.id = id
        self.arcLengthAnchor = arcLengthAnchor
        self.roadName = roadName
        self.maneuver = maneuver
    }
}

/// Catalog of maneuver anchor positions for distance-based guidance.
public struct ManeuverAnchorCatalog: Sendable, Equatable {
    /// Ordered anchors aligned with turn instructions.
    public let anchors: [ManeuverAnchor]
    /// Cumulative arc lengths for maneuver progress tracking.
    public let cumulativeArcLengths: [Double]

    /// Creates a maneuver anchor catalog.
    public init(anchors: [ManeuverAnchor], cumulativeArcLengths: [Double]) {
        self.anchors = anchors
        self.cumulativeArcLengths = cumulativeArcLengths
    }

    /// Returns the next upcoming anchor after the given arc length.
    public func nextAnchor(after arcLengthMeters: Double) -> ManeuverAnchor? {
        anchors.first { $0.arcLengthAnchor > arcLengthMeters + 1 }
    }

    /// Returns remaining distance in meters to the next maneuver anchor.
    public func distanceToNextManeuver(from arcLengthMeters: Double) -> Double? {
        guard let next = nextAnchor(after: arcLengthMeters) else { return nil }
        return max(0, next.arcLengthAnchor - arcLengthMeters)
    }

    /// Returns the anchor for a given instruction identifier.
    public func anchor(for instructionID: UUID) -> ManeuverAnchor? {
        anchors.first { $0.id == instructionID }
    }
}
