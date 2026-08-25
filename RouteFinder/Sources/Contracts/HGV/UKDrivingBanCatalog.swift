import Foundation

/// Time-windowed HGV / lorry driving ban catalog (London LCS + major EU Sunday bans).
public enum UKDrivingBanCatalog: Sendable {
    /// A circular ban zone with weekly time windows.
    public struct Zone: Sendable, Hashable {
        public let id: String
        public let label: String
        public let latitude: Double
        public let longitude: Double
        public let radiusMeters: Double
        /// Inclusive local-time windows when the ban is active.
        public let activeWindows: [TimeWindowRule]
        public let message: String

        public init(
            id: String,
            label: String,
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
            activeWindows: [TimeWindowRule],
            message: String
        ) {
            self.id = id
            self.label = label
            self.latitude = latitude
            self.longitude = longitude
            self.radiusMeters = radiusMeters
            self.activeWindows = activeWindows
            self.message = message
        }
    }

    /// Weekly local-time window for ban enforcement (hour in `0...23`).
    public struct TimeWindowRule: Sendable, Hashable {
        /// Weekdays where the rule applies (`1` = Sunday … `7` = Saturday, matching `Calendar`).
        public let weekdays: Set<Int>
        public let startHour: Int
        public let endHour: Int
        /// When `true`, the window wraps midnight (`startHour` → 24 and 0 → `endHour`).
        public let wrapsMidnight: Bool

        public init(weekdays: Set<Int>, startHour: Int, endHour: Int, wrapsMidnight: Bool = false) {
            self.weekdays = weekdays
            self.startHour = startHour
            self.endHour = endHour
            self.wrapsMidnight = wrapsMidnight
        }

        /// Returns whether `date` falls inside this rule in the given calendar/time zone.
        public func contains(_ date: Date, calendar: Calendar) -> Bool {
            let weekday = calendar.component(.weekday, from: date)
            let hour = calendar.component(.hour, from: date)
            guard weekdays.contains(weekday) else { return false }
            if wrapsMidnight {
                return hour >= startHour || hour < endHour
            }
            return hour >= startHour && hour < endHour
        }
    }

    /// Seed zones: London Lorry Control Scheme + major EU Sunday HGV bans.
    public static let zones: [Zone] = [
        // Approx Greater London / LCS overnight + weekend perimeter.
        Zone(
            id: "london-lcs",
            label: "London Lorry Control Scheme",
            latitude: 51.5074,
            longitude: -0.1278,
            radiusMeters: 22_000,
            activeWindows: [
                // Mon–Fri night: 21:00–07:00
                TimeWindowRule(weekdays: [2, 3, 4, 5, 6], startHour: 21, endHour: 7, wrapsMidnight: true),
                // Saturday afternoon into Sunday morning: 13:00 Sat → covered by Sat 13–24 + Sun all day
                TimeWindowRule(weekdays: [7], startHour: 13, endHour: 24),
                // Sunday all day
                TimeWindowRule(weekdays: [1], startHour: 0, endHour: 24),
            ],
            message: "London Lorry Control Scheme active. Check permit / permitted roads before entry."
        ),
        Zone(
            id: "germany-sunday-ban",
            label: "Germany Sunday HGV ban",
            latitude: 50.1109,
            longitude: 8.6821,
            radiusMeters: 280_000,
            activeWindows: [
                TimeWindowRule(weekdays: [1], startHour: 0, endHour: 22),
            ],
            message: "German Sunday driving ban may apply to HGVs over 7.5 t until 22:00."
        ),
        Zone(
            id: "france-sunday-ban",
            label: "France Sunday HGV ban",
            latitude: 46.6034,
            longitude: 1.8883,
            radiusMeters: 350_000,
            activeWindows: [
                TimeWindowRule(weekdays: [1], startHour: 0, endHour: 22),
            ],
            message: "French Sunday HGV ban may apply on the national network until 22:00."
        ),
        Zone(
            id: "austria-sunday-ban",
            label: "Austria weekend HGV ban",
            latitude: 47.5162,
            longitude: 14.5501,
            radiusMeters: 180_000,
            activeWindows: [
                TimeWindowRule(weekdays: [7], startHour: 15, endHour: 24),
                TimeWindowRule(weekdays: [1], startHour: 0, endHour: 22),
            ],
            message: "Austrian weekend HGV ban window active. Verify corridor exemptions."
        ),
        Zone(
            id: "switzerland-sunday-ban",
            label: "Switzerland Sunday/night HGV ban",
            latitude: 46.8182,
            longitude: 8.2275,
            radiusMeters: 120_000,
            activeWindows: [
                TimeWindowRule(weekdays: [1], startHour: 0, endHour: 24),
                TimeWindowRule(weekdays: [2, 3, 4, 5, 6, 7], startHour: 22, endHour: 5, wrapsMidnight: true),
            ],
            message: "Swiss HGV night/Sunday ban may apply. Check authorised corridors."
        ),
    ]

    /// Returns active driving-ban announcements where the route intersects known zones at `date`.
    public static func announcements(
        along route: [Coordinate],
        at date: Date,
        calendar: Calendar = .current
    ) -> [RestrictionZoneAnnouncement] {
        guard route.count >= 2 else { return [] }
        var results: [RestrictionZoneAnnouncement] = []
        var cumulative = 0.0

        let activeZones = zones.filter { zone in
            zone.activeWindows.contains { $0.contains(date, calendar: calendar) }
        }
        guard !activeZones.isEmpty else { return [] }

        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segment = haversineMeters(from, to)
            for zone in activeZones {
                let zoneCoord = Coordinate(latitude: zone.latitude, longitude: zone.longitude)
                let dFrom = haversineMeters(from, zoneCoord)
                let dTo = haversineMeters(to, zoneCoord)
                if min(dFrom, dTo) <= zone.radiusMeters {
                    let already = results.contains { $0.zoneId == zone.id }
                    if !already {
                        results.append(
                            RestrictionZoneAnnouncement(
                                kind: .noDrive,
                                label: zone.label,
                                zoneId: zone.id,
                                distanceAlongRouteMeters: cumulative,
                                message: zone.message
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
