import Contracts
import Foundation

/// Overpass-backed layby catalog that projects stops onto a route corridor.
public actor LaybyCatalogService {
    private let session: URLSession
    private var memoryCache: [String: [LaybyStop]] = [:]

    /// Creates a layby catalog service.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns laybys along the given route polyline within a cross-track corridor.
    public func laybysAlongRoute(
        _ route: [Coordinate],
        corridorHalfWidthMeters: Double = 1_200
    ) async throws -> [LaybyStop] {
        guard route.count >= 2 else { return [] }
        let cacheKey = routeCacheKey(route)
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        let paddingDegrees = max(0.02, corridorHalfWidthMeters / 111_000.0)
        let boxes = corridorBoundingBoxes(for: route, paddingDegrees: paddingDegrees)
        var collected: [LaybyStop] = []
        for box in boxes {
            let raw = try await fetchLaybys(in: box)
            collected.append(contentsOf: raw)
        }
        let projected = projectAndFilter(
            stops: deduplicated(collected),
            route: route,
            maxCrossTrackMeters: corridorHalfWidthMeters
        )
        memoryCache[cacheKey] = projected
        return projected
    }

    // MARK: - Overpass

    private func fetchLaybys(in bbox: String) async throws -> [LaybyStop] {
        let query = """
        [out:json][timeout:25];
        (
          node["highway"="rest_area"](\(bbox));
          node["highway"="services"](\(bbox));
          way["highway"="rest_area"](\(bbox));
          way["highway"="services"](\(bbox));
          node["highway"="layby"](\(bbox));
          way["highway"="layby"](\(bbox));
          node["parking"="layby"](\(bbox));
          way["parking"="layby"](\(bbox));
        );
        out center tags;
        """
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("RouteFinderLogisticsApp/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            return []
        }
        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.compactMap { element in
            let lat = element.lat ?? element.center?.lat
            let lon = element.lon ?? element.center?.lon
            guard let lat, let lon else { return nil }
            let label = element.tags?.displayName ?? "Layby"
            return LaybyStop(
                id: "layby-\(element.type)-\(element.id)",
                coordinate: Coordinate(latitude: lat, longitude: lon),
                label: label
            )
        }
    }

    // MARK: - Projection

    private func projectAndFilter(
        stops: [LaybyStop],
        route: [Coordinate],
        maxCrossTrackMeters: Double
    ) -> [LaybyStop] {
        stops.compactMap { stop -> LaybyStop? in
            guard let projection = project(point: stop.coordinate, onto: route) else { return nil }
            guard projection.crossTrackMeters <= maxCrossTrackMeters else { return nil }
            return LaybyStop(
                id: stop.id,
                coordinate: stop.coordinate,
                label: stop.label,
                arcLengthAlongRouteMeters: projection.arcLengthMeters,
                distanceFromRouteMeters: projection.crossTrackMeters
            )
        }
        .sorted { ($0.arcLengthAlongRouteMeters ?? 0) < ($1.arcLengthAlongRouteMeters ?? 0) }
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

    private func corridorBoundingBoxes(for route: [Coordinate], paddingDegrees: Double) -> [String] {
        let chunkSize = 40
        var boxes: [String] = []
        var start = 0
        while start < route.count {
            let end = min(route.count, start + chunkSize)
            let slice = Array(route[start..<end])
            let lats = slice.map(\.latitude)
            let lons = slice.map(\.longitude)
            let south = (lats.min() ?? 0) - paddingDegrees
            let north = (lats.max() ?? 0) + paddingDegrees
            let west = (lons.min() ?? 0) - paddingDegrees
            let east = (lons.max() ?? 0) + paddingDegrees
            boxes.append("\(south),\(west),\(north),\(east)")
            if end == route.count { break }
            start = end - 1
        }
        return boxes
    }

    private func deduplicated(_ stops: [LaybyStop]) -> [LaybyStop] {
        var seen = Set<String>()
        return stops.filter { seen.insert($0.id).inserted }
    }

    private func routeCacheKey(_ route: [Coordinate]) -> String {
        route.enumerated().compactMap { index, coord in
            index % 8 == 0 ? "\(coord.latitude),\(coord.longitude)" : nil
        }.joined(separator: "|")
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
        let ref: String?

        var displayName: String? {
            if let name, !name.isEmpty { return name }
            if let ref, !ref.isEmpty { return ref }
            return nil
        }
    }
}

/// Tracks upcoming laybys and advances past ones marked full.
public actor LaybyAdvisor {
    private var candidates: [LaybyStop] = []
    private var skippedIds: Set<String> = []

    /// Creates an empty advisor.
    public init() {}

    /// Replaces the candidate list for the active route.
    public func configure(candidates: [LaybyStop]) {
        self.candidates = candidates.sorted {
            ($0.arcLengthAlongRouteMeters ?? 0) < ($1.arcLengthAlongRouteMeters ?? 0)
        }
        skippedIds.removeAll()
    }

    /// Clears candidates and skip state.
    public func reset() {
        candidates = []
        skippedIds.removeAll()
    }

    /// Returns the next layby advisory ahead of the vehicle, if any.
    public func upcomingAdvisory(
        currentArcLengthMeters: Double,
        speedMps: Double
    ) -> LaybyAdvisory? {
        let ahead = candidates.first { stop in
            guard !skippedIds.contains(stop.id) else { return false }
            guard let arc = stop.arcLengthAlongRouteMeters else { return false }
            return arc >= currentArcLengthMeters - 50
        }
        guard let stop = ahead, let arc = stop.arcLengthAlongRouteMeters else { return nil }
        let remaining = max(0, arc - currentArcLengthMeters)
        let eta = speedMps > 0.5 ? remaining / speedMps : nil
        return LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: remaining,
            estimatedArrivalSeconds: eta
        )
    }

    /// Marks the current upcoming layby as full and returns the next advisory if available.
    @discardableResult
    public func markCurrentFull(
        currentArcLengthMeters: Double = 0,
        speedMps: Double = 1
    ) -> LaybyAdvisory? {
        if let current = candidates.first(where: { stop in
            guard !skippedIds.contains(stop.id) else { return false }
            guard let arc = stop.arcLengthAlongRouteMeters else { return false }
            return arc >= currentArcLengthMeters - 50
        }) {
            skippedIds.insert(current.id)
        }
        return upcomingAdvisory(currentArcLengthMeters: currentArcLengthMeters, speedMps: speedMps)
    }
}
