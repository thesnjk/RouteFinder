import Contracts
import Foundation

/// Builds maneuver anchor positions from turn instructions and route geometry.
public enum ManeuverAnchorCatalogBuilder {
    /// Creates a catalog by projecting instruction segment distances onto the route spine.
    public static func build(
        instructions: [TurnInstruction],
        totalLengthMeters: Double
    ) -> ManeuverAnchorCatalog {
        guard !instructions.isEmpty, totalLengthMeters > 0 else {
            return ManeuverAnchorCatalog(anchors: [], cumulativeArcLengths: [])
        }

        var anchors: [ManeuverAnchor] = []
        var cumulativeArcLengths: [Double] = []
        var cumulativeDistance = 0.0

        for instruction in instructions {
            anchors.append(ManeuverAnchor(
                id: instruction.id,
                arcLengthAnchor: cumulativeDistance,
                roadName: instruction.roadName,
                maneuver: instruction.maneuver
            ))
            cumulativeArcLengths.append(cumulativeDistance)
            cumulativeDistance += instruction.distance
        }

        if cumulativeDistance < totalLengthMeters,
           let last = anchors.last,
           last.maneuver != .arrive {
            let arriveInstruction = TurnInstruction(
                maneuver: .arrive,
                roadName: nil,
                distance: totalLengthMeters - cumulativeDistance,
                bearing: instructions.last?.bearing ?? 0
            )
            anchors.append(ManeuverAnchor(
                id: arriveInstruction.id,
                arcLengthAnchor: totalLengthMeters,
                roadName: nil,
                maneuver: .arrive
            ))
            cumulativeArcLengths.append(totalLengthMeters)
        }

        return ManeuverAnchorCatalog(
            anchors: anchors,
            cumulativeArcLengths: cumulativeArcLengths
        )
    }
}
