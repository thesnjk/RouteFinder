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
            guard poi.kind == .overnightSecureParking else { return poi }
            let base = poi.confidence ?? 0.8
            let multiplier: Double
            if eveningPeakHours.contains(hour) {
                multiplier = eveningPeakMultiplier
            } else if (8...16).contains(hour) {
                multiplier = daytimeMultiplier
            } else {
                multiplier = 1.0
            }
            return poi.withConfidence(base * multiplier)
        }
        return PoiConfidenceAdjuster.adjust(pois: occupancyAdjusted, reports: reports)
    }
}
