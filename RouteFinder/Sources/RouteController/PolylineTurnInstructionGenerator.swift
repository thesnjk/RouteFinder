import Contracts
import Foundation

/// Generates synthetic turn-by-turn instructions from a route polyline when ORS steps are absent.
public enum PolylineTurnInstructionGenerator {
  private static let minimumSegmentMeters = 25.0
  private static let turnThresholdDegrees = 15.0

  /// Builds turn instructions from coordinate bearing changes along the polyline.
  public static func generate(coordinates: [Coordinate]) -> [TurnInstruction] {
    guard coordinates.count >= 2 else { return [] }

    var instructions: [TurnInstruction] = [
      TurnInstruction(
        maneuver: .depart,
        roadName: nil,
        distance: 0,
        bearing: bearingBetween(coordinates[0], coordinates[1])
      ),
    ]

    var segmentDistance = 0.0
    var previousBearing = bearingBetween(coordinates[0], coordinates[1])

    for index in 1..<(coordinates.count - 1) {
      let nextBearing = bearingBetween(coordinates[index], coordinates[index + 1])
      let stepDistance = segmentLength(coordinates[index - 1], coordinates[index])
      segmentDistance += stepDistance

      let turnAngle = normalizedTurnAngle(from: previousBearing, to: nextBearing)
      let isSignificantTurn = turnAngle >= turnThresholdDegrees
      let isLongEnough = segmentDistance >= minimumSegmentMeters
      let isLast = index == coordinates.count - 2

      if (isSignificantTurn && isLongEnough) || (isLast && segmentDistance > 0) {
        let maneuver: TurnManeuver = isSignificantTurn
          ? classifyTurn(from: previousBearing, to: nextBearing)
          : .straight

        instructions.append(TurnInstruction(
          maneuver: maneuver,
          roadName: nil,
          distance: segmentDistance,
          bearing: nextBearing
        ))

        segmentDistance = 0
        previousBearing = nextBearing
      } else if isSignificantTurn {
        previousBearing = nextBearing
      }
    }

    instructions.append(TurnInstruction(
      maneuver: .arrive,
      roadName: nil,
      distance: 0,
      bearing: bearingBetween(
        coordinates[coordinates.count - 2],
        coordinates[coordinates.count - 1]
      )
    ))

    return instructions
  }

  private static func segmentLength(_ a: Coordinate, _ b: Coordinate) -> Double {
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

  private static func normalizedTurnAngle(from: Double, to: Double) -> Double {
    var diff = to - from
    while diff > 180 { diff -= 360 }
    while diff < -180 { diff += 360 }
    return abs(diff)
  }

  private static func classifyTurn(from: Double, to: Double) -> TurnManeuver {
    var diff = to - from
    while diff > 180 { diff -= 360 }
    while diff < -180 { diff += 360 }

    switch diff {
    case -180..<(-135): return .uTurn
    case -135..<(-45): return .left
    case -45..<(-15): return .slightLeft
    case -15...15: return .straight
    case 15..<45: return .slightRight
    case 45..<135: return .right
    default: return .sharpRight
    }
  }
}
