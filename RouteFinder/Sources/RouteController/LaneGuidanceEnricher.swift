import Contracts
import Foundation

/// Options controlling how lane guidance is enriched from OSM and heuristics.
public struct LaneGuidanceEnrichmentOptions: Sendable, Equatable {
    /// Maximum number of maneuvers that may trigger an Overpass query.
    public var maxOverpassManeuvers: Int
    /// Maximum arc-length from route start for Overpass queries.
    public var maxOverpassDistanceMeters: Double
    /// When false, only heuristics are applied (no network).
    public var queryOverpass: Bool
    /// Maximum concurrent Overpass requests per enrichment batch.
    public var maxConcurrentOverpassRequests: Int

    /// Default enrichment limits for route find.
    public static let `default` = LaneGuidanceEnrichmentOptions(
        maxOverpassManeuvers: 8,
        maxOverpassDistanceMeters: 50_000,
        queryOverpass: true,
        maxConcurrentOverpassRequests: 3
    )

    /// Creates enrichment options.
    public init(
        maxOverpassManeuvers: Int = 8,
        maxOverpassDistanceMeters: Double = 50_000,
        queryOverpass: Bool = true,
        maxConcurrentOverpassRequests: Int = 3
    ) {
        self.maxOverpassManeuvers = max(0, maxOverpassManeuvers)
        self.maxOverpassDistanceMeters = max(0, maxOverpassDistanceMeters)
        self.queryOverpass = queryOverpass
        self.maxConcurrentOverpassRequests = max(1, maxConcurrentOverpassRequests)
    }
}

/// Fetches lane guidance for enrichment (Overpass-backed).
public protocol LaneGuidanceFetching: Sendable {
  /// Fetches lane guidance near a maneuver coordinate.
  func fetchLaneGuidance(
    near coordinate: RoutingCoordinate,
    searchRadiusMeters: Double,
    maneuver: TurnManeuver?
  ) async throws -> LaneGuidance?
}

extension OverpassLaneGuidanceClient: LaneGuidanceFetching {}

/// Enriches turn instructions with OSM lane guidance and maneuver heuristics.
public enum LaneGuidanceEnricher: Sendable {
  private struct OverpassCandidate: Sendable {
    let index: Int
    let coordinate: RoutingCoordinate
    let maneuver: TurnManeuver
  }

  /// Applies heuristic lane guidance synchronously (no network).
  public static func enrichWithHeuristics(
    instructions: [TurnInstruction]
  ) -> [TurnInstruction] {
    guard !instructions.isEmpty else { return instructions }

    return instructions.map { instruction in
      guard instruction.laneGuidance == nil else { return instruction }
      guard instruction.maneuver != .arrive, instruction.maneuver != .depart else {
        return instruction
      }
      return instruction.replacing(
        laneGuidance: TurnLanesParser.heuristic(for: instruction.maneuver)
      )
    }
  }

  /// Enriches instructions using capped Overpass `turn:lanes` queries plus heuristics.
  public static func enrichWithOverpass(
    instructions: [TurnInstruction],
    coordinates: [Coordinate],
    options: LaneGuidanceEnrichmentOptions = .default,
    client: any LaneGuidanceFetching = OverpassLaneGuidanceClient()
  ) async -> [TurnInstruction] {
    guard !instructions.isEmpty, coordinates.count >= 2 else { return instructions }
    guard options.queryOverpass else {
      return enrichWithHeuristics(instructions: instructions)
    }

    var candidates: [OverpassCandidate] = []
    candidates.reserveCapacity(min(options.maxOverpassManeuvers, instructions.count))
    var cumulativeDistance = 0.0
    var overpassQueries = 0

    for (index, instruction) in instructions.enumerated() {
      let shouldQueryOverpass = instruction.maneuver != .arrive
        && instruction.maneuver != .depart
        && overpassQueries < options.maxOverpassManeuvers
        && cumulativeDistance <= options.maxOverpassDistanceMeters

      if shouldQueryOverpass {
        overpassQueries += 1
        let maneuverCoordinate = coordinate(
          forDistance: cumulativeDistance,
          coordinates: coordinates
        )
        candidates.append(
          OverpassCandidate(
            index: index,
            coordinate: RoutingCoordinate(
              latitude: maneuverCoordinate.latitude,
              longitude: maneuverCoordinate.longitude
            ),
            maneuver: instruction.maneuver
          )
        )
      }

      cumulativeDistance += instruction.distance
    }

    let overpassResults = await fetchOverpassGuidance(
      candidates: candidates,
      options: options,
      client: client
    )

    return instructions.enumerated().map { index, instruction in
      var laneGuidance = instruction.laneGuidance
      if let osmGuidance = overpassResults[index] {
        laneGuidance = osmGuidance ?? laneGuidance
      }

      if laneGuidance == nil,
         instruction.maneuver != .arrive,
         instruction.maneuver != .depart {
        laneGuidance = TurnLanesParser.heuristic(for: instruction.maneuver)
      }

      return instruction.replacing(laneGuidance: laneGuidance)
    }
  }

  /// Legacy entry point: heuristics first, then capped Overpass enrichment.
  public static func enrich(
    instructions: [TurnInstruction],
    coordinates: [Coordinate],
    options: LaneGuidanceEnrichmentOptions = .default,
    client: any LaneGuidanceFetching = OverpassLaneGuidanceClient()
  ) async -> [TurnInstruction] {
    let heuristic = enrichWithHeuristics(instructions: instructions)
    return await enrichWithOverpass(
      instructions: heuristic,
      coordinates: coordinates,
      options: options,
      client: client
    )
  }

  private static func fetchOverpassGuidance(
    candidates: [OverpassCandidate],
    options: LaneGuidanceEnrichmentOptions,
    client: any LaneGuidanceFetching
  ) async -> [Int: LaneGuidance?] {
    guard !candidates.isEmpty else { return [:] }

    var results: [Int: LaneGuidance?] = [:]
    results.reserveCapacity(candidates.count)
    let batchSize = options.maxConcurrentOverpassRequests

    var batchStart = 0
    while batchStart < candidates.count {
      if Task.isCancelled { break }

      let batchEnd = min(batchStart + batchSize, candidates.count)
      let batch = Array(candidates[batchStart..<batchEnd])

      await withTaskGroup(of: (Int, LaneGuidance?).self) { group in
        for candidate in batch {
          group.addTask {
            let guidance = try? await client.fetchLaneGuidance(
              near: candidate.coordinate,
              searchRadiusMeters: 35,
              maneuver: candidate.maneuver
            )
            return (candidate.index, guidance)
          }
        }

        for await result in group {
          results[result.0] = result.1
        }
      }

      batchStart = batchEnd
    }

    return results
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

private extension TurnInstruction {
  func replacing(laneGuidance: LaneGuidance?) -> TurnInstruction {
    TurnInstruction(
      id: id,
      maneuver: maneuver,
      roadName: roadName,
      distance: distance,
      bearing: bearing,
      recommendedSpeedKmh: recommendedSpeedKmh,
      laneGuidance: laneGuidance
    )
  }
}
