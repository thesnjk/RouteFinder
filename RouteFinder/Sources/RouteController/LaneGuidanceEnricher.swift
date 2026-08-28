import Contracts
import Foundation

/// Enriches turn instructions with OSM lane guidance and maneuver heuristics.
public enum LaneGuidanceEnricher: Sendable {
  private static let client = OverpassLaneGuidanceClient()

  /// Enriches instructions using Overpass `turn:lanes` near each maneuver coordinate.
  public static func enrich(
    instructions: [TurnInstruction],
    coordinates: [Coordinate]
  ) async -> [TurnInstruction] {
    guard !instructions.isEmpty, coordinates.count >= 2 else { return instructions }

  var cumulativeDistance = 0.0
  var enriched: [TurnInstruction] = []
  enriched.reserveCapacity(instructions.count)

  for (index, instruction) in instructions.enumerated() {
    if instruction.laneGuidance != nil {
      enriched.append(instruction)
      cumulativeDistance += instruction.distance
      continue
    }

    let maneuverCoordinate = coordinate(
      forDistance: cumulativeDistance,
      coordinates: coordinates
    )
    let routingCoordinate = RoutingCoordinate(
      latitude: maneuverCoordinate.latitude,
      longitude: maneuverCoordinate.longitude
    )

    var laneGuidance: LaneGuidance?
    if instruction.maneuver != .arrive, instruction.maneuver != .depart {
      laneGuidance = try? await client.fetchLaneGuidance(near: routingCoordinate)
      if laneGuidance == nil {
        laneGuidance = TurnLanesParser.heuristic(for: instruction.maneuver)
      }
    }

    enriched.append(
      TurnInstruction(
        id: instruction.id,
        maneuver: instruction.maneuver,
        roadName: instruction.roadName,
        distance: instruction.distance,
        bearing: instruction.bearing,
        recommendedSpeedKmh: instruction.recommendedSpeedKmh,
        laneGuidance: laneGuidance
      )
    )
    cumulativeDistance += instruction.distance
    _ = index
  }

  return enriched
  }

  private static func coordinate(forDistance distance: Double, coordinates: [Coordinate]) -> Coordinate {
    guard coordinates.count >= 2 else { return coordinates.first ?? Coordinate(latitude: 0, longitude: 0) }
    var travelled = 0.0
    for index in 0..<(coordinates.count - 1) {
      let segment = haversine(coordinates[index], coordinates[index + 1])
      travelled += segment
      if travelled >= distance {
        return coordinates[index + 1]
      }
    }
    return coordinates[coordinates.count - 1]
  }

  private static func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
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
}
