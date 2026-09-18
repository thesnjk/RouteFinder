import Contracts
import DataLayer
import Foundation

/// Overpass client for OSM `turn:lanes` tags near maneuver coordinates.
public struct OverpassLaneGuidanceClient: Sendable {
    private static let interpreterURL = "https://overpass-api.de/api/interpreter"
    private static let requestTimeoutSeconds: TimeInterval = 15

    private let session: URLSession
    private let cache: OverpassLaneGuidanceCache

    /// Creates an Overpass lane guidance client.
    public init(
        session: URLSession = SecureURLSession.shared,
        cache: OverpassLaneGuidanceCache = .shared
    ) {
        self.session = session
        self.cache = cache
    }

    /// Clears the shared in-memory lane guidance cache.
    public static func clearCache() {
        OverpassLaneGuidanceCache.shared.clear()
    }

    /// Fetches lane guidance near a maneuver coordinate.
    public func fetchLaneGuidance(
        near coordinate: RoutingCoordinate,
        searchRadiusMeters: Double = 35,
        maneuver: TurnManeuver? = nil
    ) async throws -> LaneGuidance? {
        if let cachedTurnLanes = cache.cachedTurnLanes(for: coordinate) {
            guard let turnLanes = cachedTurnLanes else { return nil }
            return TurnLanesParser.parse(turnLanes: turnLanes, forManeuver: maneuver)
        }

        let query = """
        [out:json][timeout:15];
        (
          way(around:\(Int(searchRadiusMeters)),\(coordinate.latitude),\(coordinate.longitude))["turn:lanes"];
          way(around:\(Int(searchRadiusMeters)),\(coordinate.latitude),\(coordinate.longitude))["turn:lanes:forward"];
          way(around:\(Int(searchRadiusMeters)),\(coordinate.latitude),\(coordinate.longitude))["turn:lanes:backward"];
          way(around:\(Int(searchRadiusMeters)),\(coordinate.latitude),\(coordinate.longitude))["destination:lanes"];
        );
        out tags;
        """
        guard let url = URL(string: Self.interpreterURL) else {
            throw OverpassLaneGuidanceError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            .data(using: .utf8)
        request.timeoutInterval = Self.requestTimeoutSeconds
        request.applyAppIdentity()

        guard request.isSecureHTTPS else {
            throw OverpassLaneGuidanceError.invalidConfiguration
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OverpassLaneGuidanceError.serverError(status: status)
        }

        let envelope = try JSONDecoder().decode(OverpassLaneResponse.self, from: data)
        let turnLanes = Self.richestTurnLanesTag(in: envelope.elements)
        cache.store(turnLanes: turnLanes, for: coordinate)

        guard let turnLanes else { return nil }
        return TurnLanesParser.parse(turnLanes: turnLanes, forManeuver: maneuver)
    }

    /// Prefers the richest lane tag: turn:lanes > forward > backward > destination:lanes.
    public static func richestTurnLanesTag(from tagMaps: [[String: String]]) -> String? {
        let priorityKeys = ["turn:lanes", "turn:lanes:forward", "turn:lanes:backward", "destination:lanes"]
        var best: String?
        var bestScore = -1
        for tags in tagMaps {
            for (rank, key) in priorityKeys.enumerated() {
                guard let value = tags[key], !value.isEmpty else { continue }
                let richness = value.split(separator: "|").count * 10 - rank
                if richness > bestScore {
                    bestScore = richness
                    best = value
                }
            }
        }
        return best
    }

    private static func richestTurnLanesTag(in elements: [OverpassLaneElement]) -> String? {
        richestTurnLanesTag(from: elements.compactMap(\.tags))
    }
}

/// Errors from the Overpass lane guidance client.
public enum OverpassLaneGuidanceError: Error, Sendable {
    case invalidConfiguration
    case serverError(status: Int)
}

private struct OverpassLaneResponse: Decodable {
    let elements: [OverpassLaneElement]
}

private struct OverpassLaneElement: Decodable {
    let tags: [String: String]?
}
