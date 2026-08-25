import Contracts
import Foundation

/// Overpass-backed truck POI repository with disk cache for offline-friendly reloads.
public actor OverpassTruckPoiRepository: TruckPoiRepositoryPort {
    private let session: URLSession
    private let diskCache: TruckPoiDiskCache
    private var memoryCache: [String: [TruckPoi]] = [:]

    public init(session: URLSession = .shared, diskCache: TruckPoiDiskCache = TruckPoiDiskCache()) {
        self.session = session
        self.diskCache = diskCache
    }

    public func query(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        profile: VehiclePhysicalVector
    ) async throws -> [TruckPoi] {
        let bbox = "\(minLat),\(minLon),\(maxLat),\(maxLon)"
        let raw = try await fetchPOIs(in: bbox)
        return CommercialPoiEngine.query(
            pois: raw,
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            profile: profile
        )
    }

    public func queryAlongRoute(
        route: [Coordinate],
        kinds: Set<TruckPoiKind>,
        aheadMeters: Double,
        fromArcLengthMeters: Double,
        corridorHalfWidthMeters: Double,
        profile: VehiclePhysicalVector
    ) async throws -> [TruckPoi] {
        guard route.count >= 2 else { return [] }
        let cacheKey = routeCacheKey(route, kinds: kinds)

        let all: [TruckPoi]
        if let memory = memoryCache[cacheKey] {
            all = memory
        } else if let disk = await diskCache.load(key: cacheKey) {
            memoryCache[cacheKey] = disk
            all = disk
        } else {
            let bboxes = corridorBoundingBoxes(for: route, paddingDegrees: 0.02)
            var collected: [TruckPoi] = []
            for bbox in bboxes {
                collected.append(contentsOf: try await fetchPOIs(in: bbox))
            }
            let projected = projectAndFilter(
                pois: deduplicated(collected),
                route: route,
                maxCrossTrackMeters: corridorHalfWidthMeters
            )
            let filtered: [TruckPoi]
            if projected.isEmpty {
                filtered = []
            } else {
                filtered = CommercialPoiEngine.query(
                    pois: projected,
                    minLat: projected.map(\.latitude).min() ?? 0,
                    maxLat: projected.map(\.latitude).max() ?? 0,
                    minLon: projected.map(\.longitude).min() ?? 0,
                    maxLon: projected.map(\.longitude).max() ?? 0,
                    profile: profile
                )
            }
            memoryCache[cacheKey] = filtered
            await diskCache.store(filtered, forKey: cacheKey)
            all = filtered
        }

        return CommercialPoiEngine.ahead(
            pois: all,
            fromArcLengthMeters: fromArcLengthMeters,
            aheadMeters: aheadMeters,
            kinds: kinds
        )
    }

    // MARK: - Overpass

    private func fetchPOIs(in bbox: String) async throws -> [TruckPoi] {
        let query = """
        [out:json][timeout:25];
        (
          node["amenity"="fuel"]["hgv"~"yes|designated"](\(bbox));
          node["amenity"="fuel"]["fuel:hgv"="yes"](\(bbox));
          node["amenity"="fuel"]["truck"="yes"](\(bbox));
          node["amenity"="fuel"]["name"~"Truck|HGV|lorry",i](\(bbox));
          node["highway"="services"](\(bbox));
          node["amenity"="parking"]["hgv"~"yes|designated"](\(bbox));
          node["amenity"="parking"]["truck"="yes"](\(bbox));
          node["highway"="rest_area"](\(bbox));
          node["man_made"="weighbridge"](\(bbox));
          node["highway"="weigh_station"](\(bbox));
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

        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.compactMap { element -> TruckPoi? in
            guard let lat = element.lat ?? element.center?.lat,
                  let lon = element.lon ?? element.center?.lon else {
                return nil
            }
            let kind = classify(tags: element.tags)
            let label = element.tags?.displayName ?? defaultLabel(for: kind)
            return TruckPoi(
                id: "\(element.type)/\(element.id)",
                kind: kind,
                latitude: lat,
                longitude: lon,
                label: label,
                amenities: amenities(from: element.tags),
                maxHeightMeters: element.tags?.maxHeightMeters,
                maxLengthMeters: element.tags?.maxLengthMeters,
                hgvAccess: true,
                confidence: 0.8
            )
        }
    }

    private func classify(tags: OverpassTags?) -> TruckPoiKind {
        guard let tags else { return .layby }
        if tags.manMade == "weighbridge" || tags.highway == "weigh_station" {
            return .weighStation
        }
        if tags.amenity == "fuel" {
            return .highFlowDiesel
        }
        if tags.amenity == "parking", tags.access == "customers" || tags.supervised == "yes" {
            return .overnightSecureParking
        }
        if tags.hazardous == "yes" || tags.hazmat == "yes" {
            return .adrCompatibleParking
        }
        if tags.highway == "rest_area" || tags.highway == "services" {
            return .layby
        }
        if tags.amenity == "parking" {
            return .overnightSecureParking
        }
        return .layby
    }

    private func amenities(from tags: OverpassTags?) -> Set<String> {
        var result = Set<String>()
        if tags?.amenity == "fuel" { result.insert("fuel") }
        if tags?.toilets == "yes" { result.insert("toilets") }
        if tags?.shower == "yes" { result.insert("shower") }
        if tags?.hgv == "yes" || tags?.hgv == "designated" { result.insert("hgv") }
        return result
    }

    private func defaultLabel(for kind: TruckPoiKind) -> String {
        switch kind {
        case .highFlowDiesel: "HGV fuel"
        case .weighStation: "Weighbridge"
        case .overnightSecureParking: "Truck parking"
        case .adrCompatibleParking: "ADR parking"
        case .layby: "Layby"
        }
    }

    // MARK: - Projection (mirrors LaybyCatalogService)

    private func projectAndFilter(
        pois: [TruckPoi],
        route: [Coordinate],
        maxCrossTrackMeters: Double
    ) -> [TruckPoi] {
        pois.compactMap { poi -> TruckPoi? in
            let point = Coordinate(latitude: poi.latitude, longitude: poi.longitude)
            guard let projection = project(point: point, onto: route) else { return nil }
            guard projection.crossTrackMeters <= maxCrossTrackMeters else { return nil }
            return TruckPoi(
                id: poi.id,
                kind: poi.kind,
                latitude: poi.latitude,
                longitude: poi.longitude,
                label: poi.label,
                amenities: poi.amenities,
                maxHeightMeters: poi.maxHeightMeters,
                maxLengthMeters: poi.maxLengthMeters,
                hgvAccess: poi.hgvAccess,
                arcLengthAlongRouteMeters: projection.arcLengthMeters,
                distanceFromRouteMeters: projection.crossTrackMeters,
                confidence: poi.confidence
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

    private func deduplicated(_ pois: [TruckPoi]) -> [TruckPoi] {
        var seen = Set<String>()
        return pois.filter { seen.insert($0.id).inserted }
    }

    private func routeCacheKey(_ route: [Coordinate], kinds: Set<TruckPoiKind>) -> String {
        let sample = route.enumerated().compactMap { index, coord in
            index % 8 == 0 ? "\(coord.latitude),\(coord.longitude)" : nil
        }
        let kindKey = kinds.map(\.rawValue).sorted().joined(separator: ",")
        return sample.joined(separator: "|") + "|" + kindKey
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
        let operatorTag: String?
        let amenity: String?
        let highway: String?
        let manMade: String?
        let hgv: String?
        let access: String?
        let supervised: String?
        let hazardous: String?
        let hazmat: String?
        let toilets: String?
        let shower: String?
        let maxheight: String?
        let maxlength: String?

        enum CodingKeys: String, CodingKey {
            case name, ref, amenity, highway, hgv, access, supervised, hazardous, hazmat, toilets, shower
            case maxheight, maxlength
            case operatorTag = "operator"
            case manMade = "man_made"
        }

        var displayName: String? {
            if let name, !name.isEmpty { return name }
            if let ref, !ref.isEmpty { return ref }
            if let operatorTag, !operatorTag.isEmpty { return operatorTag }
            return nil
        }

        var maxHeightMeters: Double? {
            parseMeters(maxheight)
        }

        var maxLengthMeters: Double? {
            parseMeters(maxlength)
        }

        private func parseMeters(_ raw: String?) -> Double? {
            guard let raw else { return nil }
            let cleaned = raw.replacingOccurrences(of: "m", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return Double(cleaned)
        }
    }
}
