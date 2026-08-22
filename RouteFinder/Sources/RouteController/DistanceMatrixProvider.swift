import Contracts
import DataLayer
import Foundation

/// Provides distance matrices from ORS Matrix API or haversine fallback with caching.
public actor DistanceMatrixProvider {
    private static let maxCacheEntries = 20

    private let orsAPIKey: String?
    private let isHGVMode: Bool
    private let session: URLSession
    private var cache: [String: [[Double]]] = [:]
    private var cacheOrder: [String] = []

    /// Creates a distance matrix provider.
    public init(
        orsAPIKey: String? = VehicleProfileStore.loadORSAPIKey(),
        isHGVMode: Bool = true,
        session: URLSession = SecureURLSession.shared
    ) {
        self.orsAPIKey = orsAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isHGVMode = isHGVMode
        self.session = session
    }

    /// Returns a symmetric distance matrix for the given coordinates (meters).
    public func distanceMatrix(for coordinates: [RoutingCoordinate]) async -> [[Double]] {
        let cacheKey = cacheKey(for: coordinates)
        if let cached = cache[cacheKey] {
            return cached
        }

        let matrix: [[Double]]
        if let key = orsAPIKey, !key.isEmpty,
           let orsMatrix = await fetchORSMatrix(coordinates: coordinates, apiKey: key) {
            matrix = orsMatrix
        } else {
            matrix = haversineMatrix(for: coordinates)
        }

        storeInCache(key: cacheKey, matrix: matrix)
        return matrix
    }

    private func fetchORSMatrix(
        coordinates: [RoutingCoordinate],
        apiKey: String
    ) async -> [[Double]]? {
        guard let baseURL = URL(string: ORSAPIDefaults.baseURL) else { return nil }
        let path = isHGVMode ? ORSAPIDefaults.hgvMatrixPath : ORSAPIDefaults.carMatrixPath
        let matrixURL = baseURL.appending(path: path)

        var request = URLRequest(url: matrixURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")

        let locations = coordinates.map { [$0.longitude, $0.latitude] }
        let payload: [String: Any] = [
            "locations": locations,
            "metrics": ["distance"],
            "units": "m",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        guard request.isSecureHTTPS else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let envelope = try JSONDecoder().decode(ORSMatrixResponse.self, from: data)
            guard let distances = envelope.distances, distances.count == coordinates.count else {
                return nil
            }
            return distances
        } catch {
            return nil
        }
    }

    private func haversineMatrix(for coordinates: [RoutingCoordinate]) -> [[Double]] {
        let count = coordinates.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: count), count: count)
        for i in 0..<count {
            for j in 0..<count where j != i {
                matrix[i][j] = haversineMeters(coordinates[i], coordinates[j])
            }
        }
        return matrix
    }

    private func haversineMeters(_ a: RoutingCoordinate, _ b: RoutingCoordinate) -> Double {
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

    private func cacheKey(for coordinates: [RoutingCoordinate]) -> String {
        coordinates.map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }.joined(separator: "|")
    }

    private func storeInCache(key: String, matrix: [[Double]]) {
        cache[key] = matrix
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        while cacheOrder.count > Self.maxCacheEntries {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}

private struct ORSMatrixResponse: Decodable {
    let distances: [[Double]]?
}
