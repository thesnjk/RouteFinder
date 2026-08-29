import Foundation

/// Along-route hazard alert shown in the map HUD and spoken once when nearby.
public struct HazardAheadAnnouncement: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let type: HazardEventType
    public let distanceRemainingMeters: Double
    public let message: String
    public let source: String

    /// Creates a hazard-ahead announcement.
    public init(
        id: String,
        type: HazardEventType,
        distanceRemainingMeters: Double,
        message: String,
        source: String
    ) {
        self.id = id
        self.type = type
        self.distanceRemainingMeters = distanceRemainingMeters
        self.message = message
        self.source = source
    }
}

/// Formats hazard voice prompts and selects ahead hazards projected onto the route spine.
public enum HazardAheadFormatter {
    /// Default distance inside which a closure hazard is announced once.
    public static let defaultAlertDistanceMeters: Double = 3000

    /// Hazard kinds surfaced as proactive ahead alerts during navigation.
    public static let alertableTypes: Set<HazardEventType> = [.closure, .traffic]

    /// Returns whether a spoken hazard alert should fire.
    public static func shouldAnnounce(
        announcement: HazardAheadAnnouncement,
        lastAnnouncedHazardId: String?,
        alertDistanceMeters: Double = defaultAlertDistanceMeters
    ) -> Bool {
        guard alertDistanceMeters > 0 else { return false }
        guard announcement.distanceRemainingMeters <= alertDistanceMeters else { return false }
        return announcement.id != lastAnnouncedHazardId
    }

    /// Spoken prompt when a hazard enters the advisory window.
    public static func spokenPrompt(for announcement: HazardAheadAnnouncement) -> String {
        let distance = formattedDistance(announcement.distanceRemainingMeters)
        switch announcement.type {
        case .closure:
            return "Road closure reported ahead in \(distance)"
        case .traffic:
            return "Traffic reported ahead in \(distance)"
        default:
            return "Hazard reported ahead in \(distance)"
        }
    }

    /// Banner copy for the map HUD.
    public static func bannerMessage(for announcement: HazardAheadAnnouncement) -> String {
        let distance = formattedDistance(announcement.distanceRemainingMeters)
        if announcement.source.hasPrefix("tomtom:") {
            switch announcement.type {
            case .closure:
                return "Road closed ahead in \(distance)"
            case .traffic:
                return "Live traffic delay ahead in \(distance)"
            default:
                break
            }
        }
        switch announcement.type {
        case .closure:
            return "Closure ahead in \(distance)"
        case .traffic:
            return "Traffic ahead in \(distance)"
        default:
            return "Hazard ahead in \(distance)"
        }
    }

    /// Builds an ahead announcement from a TomTom live-traffic hit.
    public static func tomTomStandstillAnnouncement(
        hit: TomTomTrafficHazardHit,
        currentArcLengthMeters: Double
    ) -> HazardAheadAnnouncement? {
        let remaining = hit.arcLengthAlongRouteMeters - currentArcLengthMeters
        guard remaining > 0 else { return nil }
        let type: HazardEventType = hit.isRoadClosed ? .closure : .traffic
        let announcement = HazardAheadAnnouncement(
            id: hit.id,
            type: type,
            distanceRemainingMeters: remaining,
            message: "",
            source: "tomtom:live"
        )
        return HazardAheadAnnouncement(
            id: hit.id,
            type: type,
            distanceRemainingMeters: remaining,
            message: bannerMessage(for: announcement),
            source: "tomtom:live"
        )
    }

    /// Picks the nearest alertable hazard ahead of the current arc length on the route.
    public static func nearestAhead(
        hazards: [HazardEvent],
        crowdReports: [CrowdReport],
        route: [Coordinate],
        currentArcLengthMeters: Double,
        tomTomHits: [TomTomTrafficHazardHit] = [],
        now: Date = Date(),
        maxCrossTrackMeters: Double = 500,
        maxAheadMeters: Double = 20_000
    ) -> HazardAheadAnnouncement? {
        let candidates = mergedCandidates(hazards: hazards, crowdReports: crowdReports, now: now)
        guard route.count >= 2 else { return nil }

        var best: HazardAheadAnnouncement?
        var bestDistance = Double.greatestFiniteMagnitude

        if !candidates.isEmpty {
            for candidate in candidates {
                guard Self.alertableTypes.contains(candidate.type) else { continue }
                let point = Coordinate(latitude: candidate.latitude, longitude: candidate.longitude)
                guard let projection = project(point: point, onto: route) else { continue }
                guard projection.crossTrackMeters <= maxCrossTrackMeters else { continue }
                let remaining = projection.arcLengthMeters - currentArcLengthMeters
                guard remaining > 0, remaining <= maxAheadMeters else { continue }
                if remaining < bestDistance {
                    bestDistance = remaining
                    best = HazardAheadAnnouncement(
                        id: candidate.id,
                        type: candidate.type,
                        distanceRemainingMeters: remaining,
                        message: bannerMessage(for: HazardAheadAnnouncement(
                            id: candidate.id,
                            type: candidate.type,
                            distanceRemainingMeters: remaining,
                            message: "",
                            source: candidate.source
                        )),
                        source: candidate.source
                    )
                }
            }
        }

        for hit in tomTomHits {
            guard let announcement = tomTomStandstillAnnouncement(
                hit: hit,
                currentArcLengthMeters: currentArcLengthMeters
            ) else { continue }
            guard announcement.distanceRemainingMeters <= maxAheadMeters else { continue }
            if announcement.distanceRemainingMeters < bestDistance {
                bestDistance = announcement.distanceRemainingMeters
                best = announcement
            }
        }

        return best
    }

    /// Rebuilds in-memory hazard events from recent crowd closure/traffic reports.
    public static func promotedHazards(from crowdReports: [CrowdReport], now: Date = Date()) -> [HazardEvent] {
        let recentCutoff = now.addingTimeInterval(-45 * 60)
        return crowdReports.compactMap { report in
            guard alertableTypes.contains(report.type), report.createdAt >= recentCutoff else { return nil }
            return HazardEvent(
                id: "crowd-\(report.id)",
                latitude: report.latitude,
                longitude: report.longitude,
                radiusMeters: 90,
                type: report.type,
                severity: .moderate,
                validFrom: report.createdAt,
                validTo: report.createdAt.addingTimeInterval(45 * 60),
                source: "crowd:\(report.reporterId)"
            )
        }
    }

    private struct Candidate {
        let id: String
        let type: HazardEventType
        let latitude: Double
        let longitude: Double
        let source: String
    }

    private static func mergedCandidates(
        hazards: [HazardEvent],
        crowdReports: [CrowdReport],
        now: Date
    ) -> [Candidate] {
        var results: [Candidate] = []
        for hazard in hazards where alertableTypes.contains(hazard.type) {
            guard now >= hazard.validFrom, now <= hazard.validTo else { continue }
            results.append(Candidate(
                id: hazard.id,
                type: hazard.type,
                latitude: hazard.latitude,
                longitude: hazard.longitude,
                source: hazard.source
            ))
        }
        let recentCutoff = now.addingTimeInterval(-45 * 60)
        for report in crowdReports where alertableTypes.contains(report.type) {
            guard report.createdAt >= recentCutoff else { continue }
            results.append(Candidate(
                id: "crowd-\(report.id)",
                type: report.type,
                latitude: report.latitude,
                longitude: report.longitude,
                source: "crowd:\(report.reporterId)"
            ))
        }
        return results
    }

    private static func formattedDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000
            return km >= 10
                ? String(format: "%.0f kilometres", km)
                : String(format: "%.1f kilometres", km)
        }
        let rounded = Int(meters.rounded())
        return "\(max(50, rounded)) metres"
    }

    private struct Projection {
        let arcLengthMeters: Double
        let crossTrackMeters: Double
    }

    private static func project(point: Coordinate, onto route: [Coordinate]) -> Projection? {
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

    private static func clampProjectionParameter(point: Coordinate, from: Coordinate, to: Coordinate) -> Double {
        let dLat = to.latitude - from.latitude
        let dLon = to.longitude - from.longitude
        let lengthSquared = dLat * dLat + dLon * dLon
        guard lengthSquared > 1e-12 else { return 0 }
        let latP = point.latitude - from.latitude
        let lonP = point.longitude - from.longitude
        return max(0, min(1, (latP * dLat + lonP * dLon) / lengthSquared))
    }

    private static func crossTrackDistanceMeters(
        point: Coordinate,
        from: Coordinate,
        to: Coordinate,
        t: Double
    ) -> Double {
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
}
