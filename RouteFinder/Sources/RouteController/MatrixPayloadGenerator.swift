import Contracts
import DataLayer
import Foundation

/// Generates routing matrix payloads for waypoint optimization.
public enum MatrixPayloadGenerator {
    /// Builds the JSON payload for ORS matrix requests.
    public static func buildPayload(coordinates: [RoutingCoordinate]) -> [String: Any] {
        let locations = coordinates.map { [$0.longitude, $0.latitude] }
        return [
            "locations": locations,
            "metrics": ["duration", "distance"],
            "units": "m",
        ]
    }

    /// Parses an ORS matrix response into a routing matrix.
    public static func parseResponse(
        _ envelope: ORSMatrixEnvelope,
        locationCount: Int
    ) -> RoutingMatrix? {
        let durations = envelope.durations ?? envelope.distances
        let distances = envelope.distances ?? envelope.durations
        guard let durations,
              let distances,
              durations.count == locationCount,
              distances.count == locationCount else {
            return nil
        }
        return RoutingMatrix(
            durations: durations,
            distances: distances,
            locationIndices: Array(0..<locationCount)
        )
    }
}

/// Decoded ORS matrix API response envelope.
public struct ORSMatrixEnvelope: Decodable, Sendable {
    /// Travel durations in seconds.
    public let durations: [[Double]]?
    /// Travel distances in meters.
    public let distances: [[Double]]?
}
