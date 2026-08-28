import Contracts
import Foundation

/// Overpass-backed roadworks lookup along an active route corridor.
public actor RoadworksAlongRouteRepository {
    private let session: URLSession

    /// Creates a roadworks repository.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Queries construction / roadworks nodes along the route and projects them onto the spine.
    public func queryAlongRoute(
        route: [Coordinate],
        aheadMeters: Double,
        fromArcLengthMeters: Double,
        corridorHalfWidthMeters: Double
    ) async throws -> [RoadworkSite] {
        guard route.count >= 2 else { return [] }
        let bbox = corridorBoundingBox(for: route, paddingDegrees: 0.02)
        let raw = try await fetchRoadworks(in: bbox)
        let projected = projectAndFilter(
            sites: raw,
            route: route,
            maxCrossTrackMeters: corridorHalfWidthMeters
        )
        let end = fromArcLengthMeters + aheadMeters
        return projected.filter { site in
            guard let arc = site.arcLengthAlongRouteMeters else { return false }
            return arc >= fromArcLengthMeters && arc <= end
        }
        .sorted { ($0.arcLengthAlongRouteMeters ?? 0) < ($1.arcLengthAlongRouteMeters ?? 0) }
    }

    /// Parses Overpass JSON fixture data for unit tests.
    public static func parseFixture(data: Data) throws -> [RoadworkSite] {
        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.compactMap { element -> RoadworkSite? in
            guard let lat = element.lat ?? element.center?.lat,
                  let lon = element.lon ?? element.center?.lon else {
                return nil
            }
            let label = element.tags?.name ?? element.tags?.descriptionTag ?? "Roadworks"
            return RoadworkSite(
                id: "\(element.type)/\(element.id)",
                label: label,
                latitude: lat,
                longitude: lon
            )
        }
    }

    private func fetchRoadworks(in bbox: String) async throws -> [RoadworkSite] {
        let query = """
        [out:json][timeout:25];
        (
          node["highway"="construction"](\(bbox));
          way["highway"="construction"](\(bbox));
          node["construction"](\(bbox));
        );
        out center tags;
        """
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "data", value: query)]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        return try Self.parseFixture(data: data)
    }

    private func corridorBoundingBox(for route: [Coordinate], paddingDegrees: Double) -> String {
        let lats = route.map(\.latitude)
        let lons = route.map(\.longitude)
        let south = (lats.min() ?? 0) - paddingDegrees
        let north = (lats.max() ?? 0) + paddingDegrees
        let west = (lons.min() ?? 0) - paddingDegrees
        let east = (lons.max() ?? 0) + paddingDegrees
        return "\(south),\(west),\(north),\(east)"
    }

    private func projectAndFilter(
        sites: [RoadworkSite],
        route: [Coordinate],
        maxCrossTrackMeters: Double
    ) -> [RoadworkSite] {
        sites.compactMap { site -> RoadworkSite? in
            let point = Coordinate(latitude: site.latitude, longitude: site.longitude)
            guard let projection = project(point: point, onto: route) else { return nil }
            guard projection.crossTrackMeters <= maxCrossTrackMeters else { return nil }
            return RoadworkSite(
                id: site.id,
                label: site.label,
                latitude: site.latitude,
                longitude: site.longitude,
                arcLengthAlongRouteMeters: projection.arcLengthMeters
            )
        }
    }

    private struct Projection {
        let arcLengthMeters: Double
        let crossTrackMeters: Double
    }

    private func project(point: Coordinate, onto route: [Coordinate]) -> Projection? {
        guard route.count >= 2 else { return nil }
        var cumulative: [Double] = [0]
        for index in 0..<(route.count - 1) {
            cumulative.append(cumulative[index] + haversineMeters(route[index], route[index + 1]))
        }
        var bestCrossTrack = Double.greatestFiniteMagnitude
        var bestArcLength = 0.0
        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segmentLength = haversineMeters(from, to)
            guard segmentLength > 0.5 else { continue }
            let t = clampProjectionParameter(point: point, from: from, to: to)
            let crossTrack = crossTrackDistanceMeters(point: point, from: from, to: to, t: t)
            if crossTrack < bestCrossTrack {
                bestCrossTrack = crossTrack
                bestArcLength = cumulative[index] + t * segmentLength
            }
        }
        guard bestCrossTrack < Double.greatestFiniteMagnitude else { return nil }
        return Projection(arcLengthMeters: bestArcLength, crossTrackMeters: bestCrossTrack)
    }

    private func clampProjectionParameter(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        let dLat = to.latitude - from.latitude
        let dLon = to.longitude - from.longitude
        let lengthSquared = dLat * dLat + dLon * dLon
        guard lengthSquared > 1e-12 else { return 0 }
        let latP = point.latitude - from.latitude
        let lonP = point.longitude - from.longitude
        return max(0, min(1, (latP * dLat + lonP * dLon) / lengthSquared))
    }

    private func crossTrackDistanceMeters(point: Coordinate, from: Coordinate, to: Coordinate, t: Double) -> Double {
        let proj = Coordinate(
            latitude: from.latitude + t * (to.latitude - from.latitude),
            longitude: from.longitude + t * (to.longitude - from.longitude)
        )
        return haversineMeters(point, proj)
    }

    private func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
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

    private struct OverpassResponse: Decodable {
        let elements: [OverpassElement]
    }

    private struct OverpassElement: Decodable {
        let type: String
        let id: Int64
        let lat: Double?
        let lon: Double?
        let center: OverpassCenter?
        let tags: OverpassTags?
    }

    private struct OverpassCenter: Decodable {
        let lat: Double
        let lon: Double
    }

    private struct OverpassTags: Decodable {
        let name: String?
        let descriptionTag: String?

        enum CodingKeys: String, CodingKey {
            case name
            case descriptionTag = "description"
        }
    }
}
