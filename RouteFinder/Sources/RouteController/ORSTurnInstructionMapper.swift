import Contracts
import Foundation

/// Maps OpenRouteService step maneuvers to turn-by-turn instructions.
public enum ORSTurnInstructionMapper {
    /// Converts external maneuvers into turn instructions, using coordinates for bearing when needed.
    public static func map(
        maneuvers: [ExternalManeuver],
        coordinates: [Coordinate]
    ) -> [TurnInstruction] {
        guard !maneuvers.isEmpty else { return [] }

        var instructions: [TurnInstruction] = []
        var cumulativeDistance = 0.0

        for (index, maneuver) in maneuvers.enumerated() {
            let maneuverType = mapStepType(maneuver.stepType, instruction: maneuver.instruction)
            let bearing = bearingForStep(
                index: index,
                maneuverType: maneuverType,
                coordinates: coordinates,
                cumulativeDistance: cumulativeDistance
            )

            instructions.append(TurnInstruction(
                maneuver: maneuverType,
                roadName: roadName(from: maneuver.instruction),
                distance: maneuver.distanceMeters,
                bearing: bearing
            ))

            cumulativeDistance += maneuver.distanceMeters
        }

        if instructions.last?.maneuver != .arrive, !coordinates.isEmpty {
            let lastBearing = bearingBetween(
                coordinates[max(0, coordinates.count - 2)],
                coordinates[coordinates.count - 1]
            )
            instructions.append(TurnInstruction(
                maneuver: .arrive,
                roadName: nil,
                distance: 0,
                bearing: lastBearing
            ))
        }

        return instructions
    }

    private static func mapStepType(_ type: Int?, instruction: String) -> TurnManeuver {
        guard let type else { return classifyFromInstruction(instruction) }

        switch type {
        case 0: return .straight
        case 1...5: return .depart
        case 6: return .straight
        case 7, 8: return .slightRight
        case 9, 10: return .right
        case 11, 12: return .sharpRight
        case 13, 14: return .uTurn
        case 15, 16: return .slightLeft
        case 17, 18: return .left
        case 19, 20: return .sharpLeft
        case 21...51: return .roundabout
        case 100...149: return .arrive
        default: return classifyFromInstruction(instruction)
        }
    }

    private static func classifyFromInstruction(_ instruction: String) -> TurnManeuver {
        let lower = instruction.lowercased()
        if lower.contains("arrive") || lower.contains("destination") { return .arrive }
        if lower.contains("start") || lower.contains("head") { return .depart }
        if lower.contains("u-turn") || lower.contains("uturn") { return .uTurn }
        if lower.contains("roundabout") { return .roundabout }
        if lower.contains("sharp left") { return .sharpLeft }
        if lower.contains("sharp right") { return .sharpRight }
        if lower.contains("slight left") { return .slightLeft }
        if lower.contains("slight right") { return .slightRight }
        if lower.contains("left") { return .left }
        if lower.contains("right") { return .right }
        return .straight
    }

    private static func roadName(from instruction: String) -> String? {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("head") { return nil }
        return trimmed
    }

    private static func bearingForStep(
        index: Int,
        maneuverType: TurnManeuver,
        coordinates: [Coordinate],
        cumulativeDistance: Double
    ) -> Double {
        guard coordinates.count >= 2 else { return 0 }

        if maneuverType == .depart || index == 0 {
            return bearingBetween(coordinates[0], coordinates[1])
        }

        let targetIndex = coordinateIndex(forDistance: cumulativeDistance, coordinates: coordinates)
        let fromIndex = min(targetIndex, coordinates.count - 2)
        return bearingBetween(coordinates[fromIndex], coordinates[fromIndex + 1])
    }

    private static func coordinateIndex(forDistance distance: Double, coordinates: [Coordinate]) -> Int {
        guard coordinates.count >= 2 else { return 0 }
        var travelled = 0.0
        for index in 0..<(coordinates.count - 1) {
            travelled += segmentDistance(coordinates[index], coordinates[index + 1])
            if travelled >= distance { return index + 1 }
        }
        return coordinates.count - 1
    }

    private static func segmentDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }

    private static func bearingBetween(_ from: Coordinate, _ to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
