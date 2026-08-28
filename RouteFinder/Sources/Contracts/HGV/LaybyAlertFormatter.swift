import Foundation

/// Formats layby voice prompts and driver toasts for proactive alerts.
public enum LaybyAlertFormatter {
    /// Default distance inside which a layby is announced once.
    public static let defaultAlertDistanceMeters: Double = 5000

    /// Returns whether a spoken layby alert should fire for this advisory.
    public static func shouldAnnounce(
        advisory: LaybyAdvisory,
        lastAnnouncedLaybyId: String?,
        alertDistanceMeters: Double = defaultAlertDistanceMeters
    ) -> Bool {
        guard alertDistanceMeters > 0 else { return false }
        guard advisory.distanceRemainingMeters <= alertDistanceMeters else { return false }
        return advisory.stop.id != lastAnnouncedLaybyId
    }

    /// Spoken prompt when a layby enters the advisory window.
    public static func spokenPrompt(for advisory: LaybyAdvisory) -> String {
        "Layby ahead: \(advisory.stop.label) in \(formattedETA(advisory.estimatedArrivalSeconds))"
    }

    /// Toast after the driver marks a layby full and a replacement is chosen.
    public static func nextLaybyToast(next: LaybyAdvisory?) -> String {
        guard let next else { return "No further laybys on this route" }
        return "Next layby: \(next.stop.label) in \(formattedETA(next.estimatedArrivalSeconds))"
    }

    private static func formattedETA(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds > 0 else { return "soon" }
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours) hour\(hours == 1 ? "" : "s")" : "\(hours) h \(remainder) min"
        }
        return "\(max(1, minutes)) minute\(minutes == 1 ? "" : "s")"
    }
}
