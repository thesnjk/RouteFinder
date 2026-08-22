import Contracts
import DataLayer
import Foundation

/// Overpass API client for OSM traffic signal nodes.
public struct OverpassTrafficSignalClient: Sendable {
    private static let interpreterURL = "https://overpass-api.de/api/interpreter"
    private static let requestTimeoutSeconds: TimeInterval = 15

    private let session: URLSession

    /// Creates an Overpass traffic signal client.
    public init(session: URLSession = SecureURLSession.shared) {
        self.session = session
    }

    /// Queries traffic signal nodes within a corridor around the route polyline.
    public func fetchTrafficSignals(
        along coordinates: [RoutingCoordinate],
        corridorMeters: Double = 40
    ) async throws -> [OverpassTrafficSignalNode] {
        guard coordinates.count >= 2 else { return [] }

        let query = buildQuery(coordinates: coordinates, corridorMeters: corridorMeters)
        guard let url = URL(string: Self.interpreterURL) else {
            throw OverpassTrafficSignalError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)
        request.timeoutInterval = Self.requestTimeoutSeconds
        request.applyAppIdentity()

        guard request.isSecureHTTPS else {
            throw OverpassTrafficSignalError.invalidConfiguration
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OverpassTrafficSignalError.serverError(status: status)
        }

        return try parseResponse(data: data)
    }

    private func buildQuery(coordinates: [RoutingCoordinate], corridorMeters: Double) -> String {
        let aroundPoints = coordinates.enumerated().compactMap { index, coord -> String? in
            guard index % max(1, coordinates.count / 20) == 0 else { return nil }
            return "node[\"highway\"=\"traffic_signals\"](around:\(Int(corridorMeters)),\(coord.latitude),\(coord.longitude));"
        }.joined()

        return """
        [out:json][timeout:15];
        (
        \(aroundPoints)
        );
        out body;
        """
    }

    private func parseResponse(data: Data) throws -> [OverpassTrafficSignalNode] {
        let envelope = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return envelope.elements.compactMap { element in
            guard let lat = element.lat, let lon = element.lon else { return nil }
            return OverpassTrafficSignalNode(
                id: element.id,
                coordinate: RoutingCoordinate(latitude: lat, longitude: lon),
                crossingTag: element.tags?["crossing"]
            )
        }
    }
}

/// A traffic signal node from Overpass API.
public struct OverpassTrafficSignalNode: Sendable, Hashable {
    /// OSM node ID.
    public let id: Int64
    /// Node coordinate.
    public let coordinate: RoutingCoordinate
    /// Optional OSM crossing tag for cycle customization.
    public let crossingTag: String?
}

/// Overpass API errors.
public enum OverpassTrafficSignalError: Error, Sendable, LocalizedError {
    case invalidConfiguration
    case serverError(status: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Overpass client configuration is invalid."
        case .serverError(let status):
            return "Overpass server error (HTTP \(status))."
        }
    }
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let id: Int64
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
}

extension OverpassTrafficSignalClient {
    /// Parses traffic signal nodes from raw Overpass JSON (for tests).
    public static func parseNodes(from data: Data) throws -> [OverpassTrafficSignalNode] {
        let client = OverpassTrafficSignalClient()
        return try client.parseResponse(data: data)
    }
}
