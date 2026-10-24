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

    /// Reply when speech was not recognized as a domain command.
    public static var unrecognized: String { "Sorry, I didn't catch that." }
}
