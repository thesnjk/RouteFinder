import Contracts
import Foundation

/// Hour-of-day prior that lowers overnight secure parking confidence during evening peaks.
public enum ParkingOccupancyPrior: Sendable {
    /// Local hours treated as evening occupancy peak (`17...21` inclusive).
    public static let eveningPeakHours: ClosedRange<Int> = 17...21
    /// Confidence multiplier applied to overnight secure parking during the evening peak.
    public static let eveningPeakMultiplier: Double = 0.65
    /// Mild daytime reduction outside the evening peak (still busy yards).
    public static let daytimeMultiplier: Double = 0.9
    /// Exponential age decay time constant for occupancy report weights (hours).
    public static let occupancyDecayTauHours: Double = 2.5
    /// Minimum total weight before crowd reports override the hour-of-day prior.
    public static let minimumCrowdWeight: Double = 0.2

    /// Latest driver occupancy observation for a layby (for HUD “last seen” copy).
    public struct LatestOccupancySignal: Sendable, Hashable, Equatable {
        public let kind: LaybyOccupancyReport.Kind
        public let createdAt: Date

        /// Creates a latest occupancy signal.
        public init(kind: LaybyOccupancyReport.Kind, createdAt: Date) {
            self.kind = kind
            self.createdAt = createdAt
        }

        /// Short driver-facing label (`full` / `spaces`).
        public var displayKind: String {
            switch kind {
            case .full: return "full"
            case .spacesAvailable: return "spaces"
            }
        }
    }

    /// Adjusts POI confidence using hour-of-day occupancy priors, then crowd reports.
    ///
    /// - Parameters:
    ///   - pois: Truck POIs to score.
    ///   - reports: Crowd hazard reports for ``PoiConfidenceAdjuster``.
    ///   - date: Evaluation instant (hour-of-day prior).
    ///   - calendar: Calendar for local hour extraction.
    /// - Returns: POIs with adjusted confidence in `[0, 1]`.
    public static func adjust(
        pois: [TruckPoi],
        reports: [CrowdReport],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TruckPoi] {
        let hour = calendar.component(.hour, from: date)
        let occupancyAdjusted = pois.map { poi -> TruckPoi in
            switch poi.kind {
            case .overnightSecureParking:
                let base = poi.confidence ?? 0.8
                let multiplier = secureParkingMultiplier(forHour: hour)
                return poi.withConfidence(base * multiplier)
            case .layby:
                let base = poi.confidence ?? 0.75
                let multiplier = laybyAvailabilityMultiplier(forHour: hour)
                return poi.withConfidence(base * multiplier)
            default:
                return poi
            }
        }
        return PoiConfidenceAdjuster.adjust(pois: occupancyAdjusted, reports: reports)
    }

    /// Returns a layby occupancy prior for the given arrival instant, optionally biased by nearby crowd reports.
    public static func laybyOccupancyPrior(
        at date: Date,
        for stop: LaybyStop? = nil,
        reports: [CrowdReport] = [],
        calendar: Calendar = .current,
        radiusMeters: Double = 250
    ) -> LaybyOccupancyPrior {
        if let stop, let crowdPrior = crowdOccupancyPrior(
            for: stop,
            reports: reports,
            radiusMeters: radiusMeters,
            now: date
        ) {
            return crowdPrior
        }
        let hour = calendar.component(.hour, from: date)
        let multiplier = laybyAvailabilityMultiplier(forHour: hour)
        if multiplier >= 0.95 { return .low }
        if multiplier >= 0.75 { return .moderate }
        return .high
    }

    /// Newest occupancy report for a stop (any age), used for banner last-seen copy.
    public static func latestOccupancySignal(
        for stop: LaybyStop,
        reports: [CrowdReport],
        radiusMeters: Double = 250
    ) -> LatestOccupancySignal? {
        let nearby = matchingOccupancyReports(for: stop, reports: reports, radiusMeters: radiusMeters)
        guard let newest = nearby.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
        let kind: LaybyOccupancyReport.Kind = newest.type == .laybyFull ? .full : .spacesAvailable
        return LatestOccupancySignal(kind: kind, createdAt: newest.createdAt)
    }

    /// Maps nearby driver occupancy reports onto a layby prior using age-weighted multi-report fusion.
    ///
    /// Each report is weighted by `exp(-ageHours / τ)`. Full reports push toward `.high`, spaces toward `.low`.
    /// When total weight is below ``minimumCrowdWeight``, returns `nil` so the hour-of-day prior applies.
    public static func crowdOccupancyPrior(
        for stop: LaybyStop,
        reports: [CrowdReport],
        radiusMeters: Double = 250,
        now: Date = Date()
    ) -> LaybyOccupancyPrior? {
        let nearby = matchingOccupancyReports(for: stop, reports: reports, radiusMeters: radiusMeters)
        guard !nearby.isEmpty else { return nil }

        var fullWeight = 0.0
        var spacesWeight = 0.0
        for report in nearby {
            let ageHours = max(0, now.timeIntervalSince(report.createdAt) / 3_600)
            let weight = exp(-ageHours / occupancyDecayTauHours)
            switch report.type {
            case .laybyFull:
                fullWeight += weight
            case .laybySpaces:
                spacesWeight += weight
            default:
                continue
            }
        }

        let total = fullWeight + spacesWeight
        guard total >= minimumCrowdWeight else { return nil }

        let net = (fullWeight - spacesWeight) / total
        if net >= 0.25 { return .high }
        if net <= -0.25 { return .low }
        return .moderate
    }

    private static func matchingOccupancyReports(
        for stop: LaybyStop,
        reports: [CrowdReport],
        radiusMeters: Double
    ) -> [CrowdReport] {
        reports.filter { report in
            guard report.type == .laybyFull || report.type == .laybySpaces else { return false }
            if report.note == stop.id { return true }
            return haversineMeters(
                stop.coordinate,
                Coordinate(latitude: report.latitude, longitude: report.longitude)
            ) <= radiusMeters
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

    private static func secureParkingMultiplier(forHour hour: Int) -> Double {
        if eveningPeakHours.contains(hour) {
            return eveningPeakMultiplier
        }
        if (8...16).contains(hour) {
            return daytimeMultiplier
        }
        return 1.0
    }

    private static func laybyAvailabilityMultiplier(forHour hour: Int) -> Double {
        if eveningPeakHours.contains(hour) {
            return 0.55
        }
        if (7...16).contains(hour) {
            return 0.78
        }
        return 0.95
    }
}
