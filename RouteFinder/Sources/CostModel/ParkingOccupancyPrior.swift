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

    /// Returns a layby occupancy prior for the given arrival instant.
    public static func laybyOccupancyPrior(
        at date: Date,
        calendar: Calendar = .current
    ) -> LaybyOccupancyPrior {
        let hour = calendar.component(.hour, from: date)
        let multiplier = laybyAvailabilityMultiplier(forHour: hour)
        if multiplier >= 0.95 { return .low }
        if multiplier >= 0.75 { return .moderate }
        return .high
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
