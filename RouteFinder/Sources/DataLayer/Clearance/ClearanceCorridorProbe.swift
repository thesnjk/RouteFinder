import Contracts
import Foundation

/// Overpass-backed maxheight / maxweight probe along a route corridor (clearance radar).
public actor ClearanceCorridorProbe {
    /// Soft cap on Overpass elements processed per query.
    public static let maxElements = 80
    /// Default corridor half-width including small off-route buffer (meters).
    public static let defaultCorridorHalfWidthMeters: Double = 120
    /// Default look-ahead along the spine (meters).
    public static let defaultAheadMeters: Double = 25_000
    /// Cross-track distance that triggers off-route heading clearance probes (meters).
    public static let offRouteCrossTrackThresholdMeters: Double = 75
    /// Default off-route heading probe length (meters).
    public static let defaultHeadingAheadMeters: Double = 3_000
    /// Minimum interval between off-route Overpass probes during navigation.
    public static let offRouteRefreshIntervalSeconds: TimeInterval = 90

    private let session: URLSession
    private var memoryCache: [String: [ClearanceRestrictionHit]] = [:]
    private var lastOffRouteRefresh: Date?
    private var lastOffRouteCacheKey: String?

    /// Creates a clearance corridor probe.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// A tagged restriction near the route that may conflict with the vehicle profile.
    public struct ClearanceRestrictionHit: Sendable, Hashable, Equatable {
        public let id: String
        public let latitude: Double
        public let longitude: Double
        public var arcLengthAlongRouteMeters: Double?
        public var maxHeightMeters: Double?
        public var maxWeightTonnes: Double?
        public var maxWidthMeters: Double?
        public var label: String

        public init(
            id: String,
            latitude: Double,
            longitude: Double,
            arcLengthAlongRouteMeters: Double? = nil,
            maxHeightMeters: Double? = nil,
            maxWeightTonnes: Double? = nil,
            maxWidthMeters: Double? = nil,
            label: String
        ) {
            self.id = id
            self.latitude = latitude
            self.longitude = longitude
            self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
            self.maxHeightMeters = maxHeightMeters
            self.maxWeightTonnes = maxWeightTonnes
            self.maxWidthMeters = maxWidthMeters
            self.label = label
        }
    }

    /// Queries corridor restrictions and returns advisories that conflict with ``profile``.
    public func advisoriesAlongRoute(
        route: [Coordinate],
        profile: VehicleProfile,
        currentArcLengthMeters: Double,
        aheadMeters: Double = ClearanceCorridorProbe.defaultAheadMeters,
        corridorHalfWidthMeters: Double = ClearanceCorridorProbe.defaultCorridorHalfWidthMeters
    ) async -> [RouteRiskAdvisory] {
        let hits = (try? await queryAlongRoute(
            route: route,
            aheadMeters: aheadMeters,
            fromArcLengthMeters: currentArcLengthMeters,
            corridorHalfWidthMeters: corridorHalfWidthMeters
        )) ?? []
        return Self.advisories(from: hits, profile: profile, currentArcLengthMeters: currentArcLengthMeters)
    }

    /// Builds a short polyline ahead of ``origin`` along ``bearingDegrees`` for off-route probes.
    public static func headingCorridor(
        from origin: Coordinate,
        bearingDegrees: Double,
        lengthMeters: Double = ClearanceCorridorProbe.defaultHeadingAheadMeters,
        stepMeters: Double = 250
    ) -> [Coordinate] {
        guard lengthMeters > 0, stepMeters > 0 else { return [origin] }
        var points: [Coordinate] = [origin]
        var travelled = 0.0
        while travelled < lengthMeters {
            travelled = min(lengthMeters, travelled + stepMeters)
            points.append(destinationPoint(from: origin, bearingDegrees: bearingDegrees, distanceMeters: travelled))
        }
        return points
    }

    /// True when the vehicle is farther from the route spine than the off-route threshold.
    public static func isOffRoute(
        point: Coordinate,
        route: [Coordinate],
        thresholdMeters: Double = ClearanceCorridorProbe.offRouteCrossTrackThresholdMeters
    ) -> (offRoute: Bool, crossTrackMeters: Double) {
        guard let projection = projectOntoRoute(point: point, route: route) else {
            return (true, thresholdMeters + 1)
        }
        return (projection.crossTrackMeters > thresholdMeters, projection.crossTrackMeters)
    }

    /// Probes maxheight/weight along the vehicle heading when off the planned route.
    public func advisoriesAlongHeading(
        from origin: Coordinate,
        bearingDegrees: Double,
        profile: VehicleProfile,
        aheadMeters: Double = ClearanceCorridorProbe.defaultHeadingAheadMeters,
        corridorHalfWidthMeters: Double = ClearanceCorridorProbe.defaultCorridorHalfWidthMeters,
        force: Bool = false,
        now: Date = Date()
    ) async -> [RouteRiskAdvisory] {
        if !force, let last = lastOffRouteRefresh,
           now.timeIntervalSince(last) < Self.offRouteRefreshIntervalSeconds {
            return []
        }
        let corridor = Self.headingCorridor(
            from: origin,
            bearingDegrees: bearingDegrees,
            lengthMeters: aheadMeters
        )
        let cacheKey = "heading|\(String(format: "%.4f,%.4f", origin.latitude, origin.longitude))|\(Int(bearingDegrees))|\(Int(aheadMeters))"
        let hits: [ClearanceRestrictionHit]
        if let cached = memoryCache[cacheKey], lastOffRouteCacheKey == cacheKey {
            hits = cached
        } else {
            hits = (try? await queryAlongRoute(
                route: corridor,
                aheadMeters: aheadMeters,
                fromArcLengthMeters: 0,
                corridorHalfWidthMeters: corridorHalfWidthMeters
            )) ?? []
            memoryCache[cacheKey] = hits
            lastOffRouteCacheKey = cacheKey
        }
        lastOffRouteRefresh = now
        return Self.advisories(from: hits, profile: profile, currentArcLengthMeters: 0)
            .map { advisory in
                RouteRiskAdvisory(
                    id: advisory.id,
                    kind: advisory.kind,
                    severity: advisory.severity,
                    distanceRemainingMeters: advisory.distanceRemainingMeters,
                    message: advisory.message.hasPrefix("Off-route ")
                        ? advisory.message
                        : "Off-route \(advisory.message)",
                    spokenPrompt: advisory.spokenPrompt,
                    source: "clearanceOverpassOffRoute"
                )
            }
    }

    /// Destination point ``distanceMeters`` along ``bearingDegrees`` from ``origin`` (WGS84).
    public static func destinationPoint(
        from origin: Coordinate,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> Coordinate {
        let earthRadius = 6_371_000.0
        let angularDistance = distanceMeters / earthRadius
        let bearing = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let lat2 = asin(
            sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * cos(lat2)
        )
        return Coordinate(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    /// Maps restriction hits against vehicle dims into clearance advisories (pure — for tests).
    public static func advisories(
        from hits: [ClearanceRestrictionHit],
        profile: VehicleProfile,
        currentArcLengthMeters: Double
    ) -> [RouteRiskAdvisory] {
        var items: [RouteRiskAdvisory] = []
        for hit in hits {
            let remaining = max(0, (hit.arcLengthAlongRouteMeters ?? 0) - currentArcLengthMeters)
            guard remaining > 0 || hit.arcLengthAlongRouteMeters == nil else { continue }
            var reasons: [String] = []
            var severe = false
            if let maxH = hit.maxHeightMeters, let height = profile.height, height > maxH {
                reasons.append(String(format: "height %.1fm > limit %.1fm", height, maxH))
                severe = true
            }
            if let maxW = hit.maxWidthMeters, let width = profile.width, width > maxW {
                reasons.append(String(format: "width %.2fm > limit %.2fm", width, maxW))
                severe = true
            }
            if let maxWeight = hit.maxWeightTonnes, let weight = profile.weight, weight > maxWeight {
                reasons.append(String(format: "weight %.1ft > limit %.1ft", weight, maxWeight))
                severe = true
            }
            guard !reasons.isEmpty else { continue }
            let distance = hit.arcLengthAlongRouteMeters == nil
                ? 2_000
                : max(200, remaining)
            let message = "Clearance: \(hit.label) — \(reasons.joined(separator: "; "))"
            items.append(
                RouteRiskAdvisory(
                    id: "clearance-\(hit.id)",
                    kind: .clearance,
                    severity: severe ? .severe : .caution,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "clearanceOverpass"
                )
            )
        }
        return items
    }

    /// Queries maxheight / maxweight / maxwidth nodes along the corridor.
    public func queryAlongRoute(
        route: [Coordinate],
        aheadMeters: Double,
        fromArcLengthMeters: Double,
        corridorHalfWidthMeters: Double
    ) async throws -> [ClearanceRestrictionHit] {
        guard route.count >= 2 else { return [] }
        let cacheKey = routeCacheKey(route)
        let projected: [ClearanceRestrictionHit]
        if let memory = memoryCache[cacheKey] {
            projected = memory
        } else {
            guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .overpass) else {
                return []
            }
            let bbox = corridorBoundingBox(for: route, paddingDegrees: 0.025)
            let raw = try await fetchRestrictions(in: bbox)
            projected = projectAndFilter(
                hits: raw,
                route: route,
                maxCrossTrackMeters: corridorHalfWidthMeters
            )
            memoryCache[cacheKey] = projected
        }
        let end = fromArcLengthMeters + aheadMeters
        return projected.filter { hit in
            guard let arc = hit.arcLengthAlongRouteMeters else { return true }
            return arc >= fromArcLengthMeters - 500 && arc <= end
        }
        .sorted { ($0.arcLengthAlongRouteMeters ?? 0) < ($1.arcLengthAlongRouteMeters ?? 0) }
    }

    /// Parses Overpass JSON fixture data for unit tests.
    public static func parseFixture(data: Data) throws -> [ClearanceRestrictionHit] {
        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.prefix(maxElements).compactMap { Self.hit(from: $0) }
    }

    private static func hit(from element: OverpassElement) -> ClearanceRestrictionHit? {
        guard let lat = element.lat ?? element.center?.lat,
              let lon = element.lon ?? element.center?.lon else {
            return nil
        }
        let tags = element.tags
        let maxHeight = parseMeters(tags?.maxheight)
        let maxWidth = parseMeters(tags?.maxwidth)
        let maxWeight = parseTonnes(tags?.maxweight ?? tags?.maxweightrating)
        guard maxHeight != nil || maxWidth != nil || maxWeight != nil else { return nil }
        let label = tags?.name ?? tags?.bridge ?? "restriction"
        return ClearanceRestrictionHit(
            id: "\(element.type)/\(element.id)",
            latitude: lat,
            longitude: lon,
            maxHeightMeters: maxHeight,
            maxWeightTonnes: maxWeight,
            maxWidthMeters: maxWidth,
            label: label
        )
    }

    /// Parses OSM length tags (`4.2`, `4.2 m`, `13'6"`).
    public static func parseMeters(_ raw: String?) -> Double? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty,
              raw != "default",
              raw != "none" else { return nil }
        if let meters = Double(raw.replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces)) {
            return meters
        }
        // Feet'inches"
        if raw.contains("'") {
            let parts = raw.replacingOccurrences(of: "\"", with: "").split(separator: "'")
            let feet = Double(parts.first ?? "") ?? 0
            let inches = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
            return (feet * 12 + inches) * 0.0254
        }
        return nil
    }

    /// Parses OSM weight tags (`7.5`, `7.5 t`, `18000 kg`).
    public static func parseTonnes(_ raw: String?) -> Double? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else { return nil }
        if raw.contains("kg") {
            let value = Double(raw.replacingOccurrences(of: "kg", with: "").trimmingCharacters(in: .whitespaces))
            return value.map { $0 / 1_000 }
        }
        let cleaned = raw.replacingOccurrences(of: "t", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private func fetchRestrictions(in bbox: String) async throws -> [ClearanceRestrictionHit] {
        let query = """
        [out:json][timeout:25];
        (
          node["maxheight"](\(bbox));
          way["maxheight"](\(bbox));
          node["maxweight"](\(bbox));
          way["maxweight"](\(bbox));
          node["maxwidth"](\(bbox));
          way["maxwidth"](\(bbox));
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
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        await APIUsageLedger.shared.record(provider: .overpass)
        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        return decoded.elements.prefix(Self.maxElements).compactMap { Self.hit(from: $0) }
    }

    private func routeCacheKey(_ route: [Coordinate]) -> String {
        let sample = route.enumerated().compactMap { index, coord in
            index % 8 == 0 ? "\(coord.latitude),\(coord.longitude)" : nil
        }
        return sample.joined(separator: "|") + "|clearance"
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
        hits: [ClearanceRestrictionHit],
        route: [Coordinate],
        maxCrossTrackMeters: Double
    ) -> [ClearanceRestrictionHit] {
        hits.compactMap { hit in
            let point = Coordinate(latitude: hit.latitude, longitude: hit.longitude)
            guard let projection = Self.projectOntoRoute(point: point, route: route),
                  projection.crossTrackMeters <= maxCrossTrackMeters else {
                return nil
            }
            var copy = hit
            copy.arcLengthAlongRouteMeters = projection.arcLengthMeters
            return copy
        }
    }

    private static func projectOntoRoute(
        point: Coordinate,
        route: [Coordinate]
    ) -> (arcLengthMeters: Double, crossTrackMeters: Double)? {
        guard route.count >= 2 else { return nil }
        var bestCross = Double.greatestFiniteMagnitude
        var bestArc = 0.0
        var cumulative = 0.0
        for index in 0..<(route.count - 1) {
            let a = route[index]
            let b = route[index + 1]
            let segment = haversineMeters(a, b)
            let t = max(0, min(1, projectT(point: point, from: a, to: b)))
            let cross = crossTrackDistanceMeters(point: point, from: a, to: b, t: t)
            let arc = cumulative + t * segment
            if cross < bestCross {
                bestCross = cross
                bestArc = arc
            }
            cumulative += segment
        }
        return (bestArc, bestCross)
    }

    private func project(
        point: Coordinate,
        onto route: [Coordinate]
    ) -> (arcLengthMeters: Double, crossTrackMeters: Double)? {
        Self.projectOntoRoute(point: point, route: route)
    }

    private static func projectT(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        let dx = to.longitude - from.longitude
        let dy = to.latitude - from.latitude
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return 0 }
        return ((point.longitude - from.longitude) * dx + (point.latitude - from.latitude) * dy) / len2
    }

    private static func crossTrackDistanceMeters(point: Coordinate, from: Coordinate, to: Coordinate, t: Double) -> Double {
        let proj = Coordinate(
            latitude: from.latitude + t * (to.latitude - from.latitude),
            longitude: from.longitude + t * (to.longitude - from.longitude)
        )
        return haversineMeters(point, proj)
    }

    private static func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
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
        let bridge: String?
        let maxheight: String?
        let maxwidth: String?
        let maxweight: String?
        let maxweightrating: String?
    }
}
