import Foundation

/// Restriction / LEZ announcement for along-route driver UX.
public struct RestrictionZoneAnnouncement: Sendable, Hashable, Codable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case lez
        case residentialBan
        case hgvBanned
        case noDrive
    }

    public let id: String
    public let kind: Kind
    public let label: String
    public let zoneId: String?
    public let distanceAlongRouteMeters: Double
    public let message: String

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        label: String,
        zoneId: String? = nil,
        distanceAlongRouteMeters: Double,
        message: String
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.zoneId = zoneId
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
        self.message = message
    }
}

/// Seed catalog of major UK low-emission / clean-air zones for along-route alerts.
public enum UKLowEmissionZoneCatalog: Sendable {
    public struct Zone: Sendable, Hashable {
        public let id: String
        public let label: String
        public let latitude: Double
        public let longitude: Double
        /// Approximate zone radius in meters for corridor intersection.
        public let radiusMeters: Double
    }

    public static let zones: [Zone] = [
        Zone(id: "london-ulez", label: "London ULEZ", latitude: 51.5074, longitude: -0.1278, radiusMeters: 18_000),
        Zone(id: "birmingham-caz", label: "Birmingham CAZ", latitude: 52.4862, longitude: -1.8904, radiusMeters: 4_000),
        Zone(id: "bristol-caz", label: "Bristol CAZ", latitude: 51.4545, longitude: -2.5879, radiusMeters: 3_500),
        Zone(id: "sheffield-caz", label: "Sheffield CAZ", latitude: 53.3811, longitude: -1.4701, radiusMeters: 3_500),
        Zone(id: "bath-caz", label: "Bath CAZ", latitude: 51.3811, longitude: -2.3590, radiusMeters: 2_500),
        Zone(id: "newcastle-caz", label: "Newcastle CAZ", latitude: 54.9783, longitude: -1.6178, radiusMeters: 3_000),
    ]

    /// Returns LEZ announcements where the route polyline intersects known UK zones.
    public static func announcements(along route: [Coordinate]) -> [RestrictionZoneAnnouncement] {
        guard route.count >= 2 else { return [] }
        var results: [RestrictionZoneAnnouncement] = []
        var cumulative = 0.0

        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segment = haversineMeters(from, to)
            for zone in zones {
                let zoneCoord = Coordinate(latitude: zone.latitude, longitude: zone.longitude)
                let dFrom = haversineMeters(from, zoneCoord)
                let dTo = haversineMeters(to, zoneCoord)
                if min(dFrom, dTo) <= zone.radiusMeters {
                    let already = results.contains { $0.zoneId == zone.id }
                    if !already {
                        results.append(
                            RestrictionZoneAnnouncement(
                                kind: .lez,
                                label: zone.label,
                                zoneId: zone.id,
                                distanceAlongRouteMeters: cumulative,
                                message: "\(zone.label) ahead. Check vehicle compliance before entry."
                            )
                        )
                    }
                }
            }
            cumulative += segment
        }
        return results.sorted { $0.distanceAlongRouteMeters < $1.distanceAlongRouteMeters }
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
}

/// Adjusts truck POI confidence from nearby crowd hazard reports.
public enum PoiConfidenceAdjuster: Sendable {
    /// Applies crowd reports within `radiusMeters` to reduce or reinforce POI confidence.
    public static func adjust(
        pois: [TruckPoi],
        reports: [CrowdReport],
        radiusMeters: Double = 250
    ) -> [TruckPoi] {
        guard !reports.isEmpty else { return pois }
        return pois.map { poi in
            let nearby = reports.filter {
                haversineMeters(
                    Coordinate(latitude: poi.latitude, longitude: poi.longitude),
                    Coordinate(latitude: $0.latitude, longitude: $0.longitude)
                ) <= radiusMeters
            }
            guard !nearby.isEmpty else { return poi }
            var confidence = poi.confidence ?? 0.8
            for report in nearby {
                switch report.type {
                case .closure:
                    confidence -= 0.25
                case .traffic:
                    confidence -= 0.15
                case .camera:
                    confidence -= 0.05
                case .weather, .crowdReport, .other:
                    confidence -= 0.1
                }
            }
            return poi.withConfidence(confidence)
        }
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
}
