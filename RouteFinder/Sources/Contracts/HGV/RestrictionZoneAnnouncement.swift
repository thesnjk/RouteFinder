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

/// Seed catalog of major UK low-emission / clean-air zones for along-route alerts and ORS avoidance.
public enum UKLowEmissionZoneCatalog: Sendable {
    /// Approximate circular UK LEZ / CAZ for corridor checks and avoid polygons.
    public struct Zone: Sendable, Hashable {
        public let id: String
        public let label: String
        public let latitude: Double
        public let longitude: Double
        /// Approximate zone radius in meters for corridor intersection.
        public let radiusMeters: Double
        /// Lowest emission class treated as compliant for avoid-on-route.
        public let minimumCompliantClass: EmissionClass

        /// Creates a catalog zone.
        public init(
            id: String,
            label: String,
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
            minimumCompliantClass: EmissionClass = .euro6
        ) {
            self.id = id
            self.label = label
            self.latitude = latitude
            self.longitude = longitude
            self.radiusMeters = radiusMeters
            self.minimumCompliantClass = minimumCompliantClass
        }

        /// Geographic center of the approximate zone.
        public var center: Coordinate {
            Coordinate(latitude: latitude, longitude: longitude)
        }

        /// Whether `point` falls inside the approximate circular zone.
        public func contains(_ point: Coordinate) -> Bool {
            haversineMeters(center, point) <= radiusMeters
        }

        /// Closed GeoJSON-style `[lon, lat]` ring approximating the zone as an N-gon.
        ///
        /// - Parameter pointCount: Number of vertices before closing (minimum 3).
        public func avoidPolygonRing(pointCount: Int = 16) -> [[Double]] {
            let count = max(3, pointCount)
            let earthRadius = 6_371_000.0
            let angularDistance = radiusMeters / earthRadius
            let lat1 = latitude * .pi / 180
            let lon1 = longitude * .pi / 180
            var ring: [[Double]] = []
            ring.reserveCapacity(count + 1)

            for index in 0..<count {
                let bearing = 2 * .pi * Double(index) / Double(count)
                let lat2 = asin(
                    sin(lat1) * cos(angularDistance)
                        + cos(lat1) * sin(angularDistance) * cos(bearing)
                )
                let lon2 = lon1 + atan2(
                    sin(bearing) * sin(angularDistance) * cos(lat1),
                    cos(angularDistance) - sin(lat1) * sin(lat2)
                )
                ring.append([lon2 * 180 / .pi, lat2 * 180 / .pi])
            }
            if let first = ring.first {
                ring.append(first)
            }
            return ring
        }
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
    ///
    /// - Parameters:
    ///   - route: Route polyline.
    ///   - emissionClass: Active vehicle emission class (nil = unknown / treat as non-compliant).
    ///   - avoidEnabled: Whether avoid-on-route is enabled for messaging.
    ///   - destination: Trip destination used to distinguish unavoidable zones.
    public static func announcements(
        along route: [Coordinate],
        emissionClass: EmissionClass? = nil,
        avoidEnabled: Bool = false,
        destination: Coordinate? = nil
    ) -> [RestrictionZoneAnnouncement] {
        guard route.count >= 2 else { return [] }
        var results: [RestrictionZoneAnnouncement] = []
        var cumulative = 0.0

        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segment = haversineMeters(from, to)
            for zone in zones {
                let dFrom = haversineMeters(from, zone.center)
                let dTo = haversineMeters(to, zone.center)
                if min(dFrom, dTo) <= zone.radiusMeters {
                    let already = results.contains { $0.zoneId == zone.id }
                    if !already {
                        results.append(
                            RestrictionZoneAnnouncement(
                                kind: .lez,
                                label: zone.label,
                                zoneId: zone.id,
                                distanceAlongRouteMeters: cumulative,
                                message: announcementMessage(
                                    for: zone,
                                    emissionClass: emissionClass,
                                    avoidEnabled: avoidEnabled,
                                    destination: destination
                                )
                            )
                        )
                    }
                }
            }
            cumulative += segment
        }
        return results.sorted { $0.distanceAlongRouteMeters < $1.distanceAlongRouteMeters }
    }

    private static func announcementMessage(
        for zone: Zone,
        emissionClass: EmissionClass?,
        avoidEnabled: Bool,
        destination: Coordinate?
    ) -> String {
        let destinationInside = destination.map { zone.contains($0) } ?? false
        if destinationInside {
            return "Destination inside \(zone.label). Check vehicle compliance before entry."
        }
        if avoidEnabled, LEZAvoidPolicy.shouldAvoid(zone: zone, emissionClass: emissionClass) {
            return "Avoiding \(zone.label) (vehicle emission below zone requirement)."
        }
        return "\(zone.label) ahead. Check vehicle compliance before entry."
    }
}

/// Builds ORS `avoid_polygons` rings for UK LEZ / CAZ zones the vehicle is not compliant with.
public enum LEZAvoidPolicy: Sendable {
    /// Whether the vehicle should avoid `zone` based on emission class.
    ///
    /// Missing emission class is treated as non-compliant (avoid when the toggle is on).
    public static func shouldAvoid(
        zone: UKLowEmissionZoneCatalog.Zone,
        emissionClass: EmissionClass?
    ) -> Bool {
        guard let emissionClass else { return true }
        return emissionClass.euroRank < zone.minimumCompliantClass.euroRank
    }

    /// Returns closed `[lon, lat]` rings for zones to avoid on the next ORS request.
    ///
    /// Zones that contain `destination` are omitted so routing can still reach the stop.
    public static func polygons(
        emissionClass: EmissionClass?,
        avoidEnabled: Bool,
        destination: Coordinate?,
        zones: [UKLowEmissionZoneCatalog.Zone] = UKLowEmissionZoneCatalog.zones
    ) -> [[[Double]]] {
        guard avoidEnabled else { return [] }
        var rings: [[[Double]]] = []
        for zone in zones {
            guard shouldAvoid(zone: zone, emissionClass: emissionClass) else { continue }
            if let destination, zone.contains(destination) { continue }
            rings.append(zone.avoidPolygonRing())
        }
        return rings
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
                case .laybyFull:
                    confidence -= 0.35
                case .laybySpaces:
                    confidence = min(1, confidence + 0.2)
                case .weather, .crowdReport, .other:
                    confidence -= 0.1
                }
            }
            return poi.withConfidence(confidence)
        }
    }
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
