import Foundation

/// Spoken confirmation strings for driver voice-assist commands.
public enum VoiceAssistResponseFormatter: Sendable {
    /// Reply after Break Now ranks a layby (or fails).
    public static func breakNow(advisory: LaybyAdvisory?) -> String {
        guard let advisory else {
            return "No laybys found ahead on this route."
        }
        return LaybyAlertFormatter.spokenPrompt(for: advisory)
    }

    /// Reply after advancing to the next layby (or none remaining).
    public static func nextLayby(advisory: LaybyAdvisory?) -> String {
        LaybyAlertFormatter.nextLaybyToast(next: advisory)
    }

    /// Reply after opening the parking book sheet for an ahead stop.
    public static func bookParking(label: String, tier: ParkingAvailabilityTier?) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Ahead parking" : trimmed
        if let tier {
            return "Opening book options for \(name). Availability: \(tier.displayLabel). Partner site — RouteFinder does not take payment."
        }
        return "Opening book options for \(name). Partner site — RouteFinder does not take payment."
    }

    /// Reply when no ahead parking / bookable stop is available.
    public static var bookParkingNone: String {
        "No ahead parking to book on this route."
    }

    /// Reply when voice guidance is muted (prefer toast; keep short if spoken).
    public static var muted: String { "Voice guidance muted." }

    /// Reply when voice guidance is restored.
    public static var unmuted: String { "Voice guidance on." }

    /// Reply for “where am I stopping?” using layby advisory or destination label.
    public static func whereStopping(
        advisory: LaybyAdvisory?,
        destinationLabel: String?
    ) -> String {
        if let advisory {
            return LaybyAlertFormatter.spokenPrompt(for: advisory)
        }
        let trimmed = destinationLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return "Your destination is \(trimmed)."
        }
        return "No layby planned on this route."
    }

    /// Short spoken Can-I-drive answer (planning aid — not legal VU).
    public static func canIDrive(status: CanIDriveStatus?) -> String {
        guard let status else {
            return "Can I drive status is unavailable."
        }
        let remainingMinutes = max(0, Int((status.remainingContinuousDriveSeconds / 60.0).rounded()))
        if status.canDrive {
            return "Yes. About \(remainingMinutes) minutes of continuous drive remaining. Planning aid only — check your tachograph."
        }
        return "No. Do not drive until your tachograph allows. Planning aid only."
    }

    /// Spoken toll callout from the near-horizon advisory or route summary line.
    public static func tollAhead(
        tollName: String?,
        distanceMeters: Double?,
        costLabel: String?,
        routeSummary: String?
    ) -> String {
        if let tollName, !tollName.isEmpty {
            var parts = [tollName]
            if let distanceMeters {
                parts.append(distancePhrase(meters: distanceMeters))
            }
            if let costLabel, !costLabel.isEmpty {
                parts.append(costLabel)
            }
            return parts.joined(separator: ". ") + ". Indicative only — check the operator."
        }
        if let routeSummary, !routeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(routeSummary). Indicative only — check the operator."
        }
        return "No named tolls on this route."
    }

    /// Route-summary line for UI / commit TTS (names + optional indicative total). Returns `nil` when empty.
    public static func committedRouteTollSummary(advisories: [UKTollAdvisory]) -> String? {
        guard !advisories.isEmpty else { return nil }
        let names = advisories.map(\.name).joined(separator: " · ")
        if let total = UKTollAdvisory.indicativeRouteTotalLabel(advisories: advisories) {
            return "\(names) — \(total)"
        }
        return names
    }

    /// One-shot commit announcement when named tolls match; `nil` when silent (no advisories).
    public static func committedRouteTollAnnouncement(advisories: [UKTollAdvisory]) -> String? {
        guard let summary = committedRouteTollSummary(advisories: advisories) else { return nil }
        return tollAhead(
            tollName: nil,
            distanceMeters: nil,
            costLabel: nil,
            routeSummary: summary
        )
    }

    /// Stable signature for deduping commit-time toll TTS across refreshes of the same route.
    public static func tollRouteSignature(advisories: [UKTollAdvisory]) -> String {
        advisories.map(\.id).sorted().joined(separator: "|")
    }

    /// Spoken next LEZ / CAZ restriction.
    public static func nextLez(label: String?, message: String?) -> String {
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        if let label, !label.isEmpty {
            return "\(label) ahead. Geometry is approximate — not a legal boundary."
        }
        return "No low emission zones flagged on this route."
    }

    /// Spoken remaining ETA from physics or static duration seconds.
    public static func eta(remainingSeconds: TimeInterval?) -> String {
        guard let remainingSeconds, remainingSeconds.isFinite, remainingSeconds > 0 else {
            return "ETA is unavailable."
        }
        return "About \(durationPhrase(seconds: remainingSeconds)) remaining."
    }

    /// Spoken hazard / closure callout from the active ahead announcement.
    public static func hazardAhead(announcement: HazardAheadAnnouncement?) -> String {
        guard let announcement else {
            return "No hazards flagged ahead."
        }
        return HazardAheadFormatter.spokenPrompt(for: announcement)
    }

    /// Spoken roadworks callout from the nearest ahead site.
    public static func roadworksAhead(label: String?, remainingMeters: Double?) -> String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return "No roadworks flagged ahead."
        }
        if let remainingMeters, remainingMeters > 0 {
            return "\(trimmed) \(distancePhrase(meters: remainingMeters))."
        }
        return "\(trimmed) ahead along route."
    }

    /// Spoken primary fused predictive-risk advisory.
    public static func riskAhead(spokenPrompt: String?) -> String {
        let trimmed = spokenPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return "No predictive risks flagged ahead."
    }

    /// Reply when speech was not recognized as a domain command.
    public static var unrecognized: String { "Sorry, I didn't catch that." }

    private static func distancePhrase(meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "in %.1f kilometres", meters / 1000)
        }
        return "in \(Int(meters)) metres"
    }

    private static func durationPhrase(seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60.0).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) hours \(minutes) minutes"
        }
        return "\(minutes) minutes"
    }
}
