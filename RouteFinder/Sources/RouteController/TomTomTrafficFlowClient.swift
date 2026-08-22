import Contracts
import DataLayer
import Foundation

/// TomTom Traffic Flow segment data client.
public struct TomTomTrafficFlowClient: Sendable {
    private static let baseURL = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute"

    private let apiKey: String
    private let session: URLSession

    /// Creates a TomTom traffic flow client.
    public init(apiKey: String, session: URLSession = SecureURLSession.shared) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TomTomTrafficError.notConfigured
        }
        self.apiKey = trimmed
        self.session = session
    }

    /// Fetches flow segment data for a geographic point.
    public func fetchFlowSegment(at coordinate: RoutingCoordinate) async throws -> TomTomFlowSegmentData {
        var components = URLComponents(string: "\(Self.baseURL)/10/json")!
        components.queryItems = [
            URLQueryItem(name: "point", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "unit", value: "KMPH"),
            URLQueryItem(name: "key", value: apiKey),
        ]
        guard let url = components.url else {
            throw TomTomTrafficError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.applyAppIdentity()

        guard request.isSecureHTTPS else {
            throw TomTomTrafficError.invalidConfiguration
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TomTomTrafficError.serverError(status: -1)
        }
        guard http.statusCode == 200 else {
            throw TomTomTrafficError.serverError(status: http.statusCode)
        }

        let envelope = try JSONDecoder().decode(TomTomFlowResponse.self, from: data)
        guard let segment = envelope.flowSegmentData else {
            throw TomTomTrafficError.noData
        }
        return segment.asDomain
    }
}

/// Parsed TomTom flow segment data.
public struct TomTomFlowSegmentData: Sendable, Hashable {
    /// Current speed in km/h.
    public let currentSpeedKmh: Double
    /// Free-flow speed in km/h.
    public let freeFlowSpeedKmh: Double
    /// Confidence level (0–1).
    public let confidence: Double
    /// Whether the road is closed.
    public let roadClosed: Bool

    /// Congestion level derived from speed ratio.
    public var congestionLevel: TrafficCongestionLevel {
        TrafficCongestionLevel.classify(
            currentSpeedKmh: currentSpeedKmh,
            freeFlowSpeedKmh: freeFlowSpeedKmh
        )
    }

    /// Creates flow segment data.
    public init(
        currentSpeedKmh: Double,
        freeFlowSpeedKmh: Double,
        confidence: Double,
        roadClosed: Bool
    ) {
        self.currentSpeedKmh = currentSpeedKmh
        self.freeFlowSpeedKmh = freeFlowSpeedKmh
        self.confidence = confidence
        self.roadClosed = roadClosed
    }
}

/// TomTom traffic API errors.
public enum TomTomTrafficError: Error, Sendable, LocalizedError {
    case notConfigured
    case invalidConfiguration
    case serverError(status: Int)
    case noData

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "TomTom API key is not configured."
        case .invalidConfiguration:
            return "TomTom client configuration is invalid."
        case .serverError(let status):
            return "TomTom server error (HTTP \(status))."
        case .noData:
            return "No traffic flow data returned."
        }
    }
}

private struct TomTomFlowResponse: Decodable {
    let flowSegmentData: TomTomFlowSegmentDataDecodable?
}

private struct TomTomFlowSegmentDataDecodable: Decodable {
    let currentSpeed: Double
    let freeFlowSpeed: Double
    let confidence: Double
    let roadClosed: Bool?

    var asDomain: TomTomFlowSegmentData {
        TomTomFlowSegmentData(
            currentSpeedKmh: currentSpeed,
            freeFlowSpeedKmh: freeFlowSpeed,
            confidence: confidence,
            roadClosed: roadClosed ?? false
        )
    }
}

extension TomTomTrafficFlowClient {
    /// Parses flow segment from raw response data (for tests).
    public static func parseFlowSegment(from data: Data) throws -> TomTomFlowSegmentData {
        let envelope = try JSONDecoder().decode(TomTomFlowResponse.self, from: data)
        guard let segment = envelope.flowSegmentData else {
            throw TomTomTrafficError.noData
        }
        return segment.asDomain
    }
}
