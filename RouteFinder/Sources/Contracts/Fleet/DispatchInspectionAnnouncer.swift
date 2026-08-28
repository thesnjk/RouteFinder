import Foundation

/// Decides when dispatch should toast for a newly observed walkaround inspection summary.
public enum DispatchInspectionAnnouncer {
    /// Returns whether dispatch should show a toast for the polled inspection summary.
    public static func shouldAnnounce(
        previousSummary: TripBriefInspectionSummary?,
        newSummary: TripBriefInspectionSummary?,
        lastAnnounced: TripBriefInspectionSummary?
    ) -> Bool {
        guard let newSummary, newSummary.defectCount > 0 else { return false }
        if let lastAnnounced,
           lastAnnounced.completedAt == newSummary.completedAt,
           lastAnnounced.defectCount == newSummary.defectCount {
            return false
        }
        guard let previousSummary else {
            return true
        }
        if previousSummary.defectCount < newSummary.defectCount {
            return true
        }
        if previousSummary.completedAt != newSummary.completedAt {
            return true
        }
        return false
    }

    /// Driver-facing toast copy for dispatch when defects are reported.
    public static func toastMessage(for summary: TripBriefInspectionSummary) -> String {
        let plateSuffix = summary.registrationPlate.map { " (\($0))" } ?? ""
        return "Walkaround: \(summary.vehicleLabel)\(plateSuffix) — \(summary.defectCount) defect(s) reported"
    }
}
