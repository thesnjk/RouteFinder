import Foundation

/// Domain voice commands for hands-free driver assist (push-to-talk).
public enum DriverVoiceCommand: String, Sendable, Equatable, CaseIterable {
    /// Rank nearest layby ahead (Break Now).
    case breakNow
    /// Skip current layby and advance to the next candidate.
    case nextLayby
    /// Mute turn-by-turn and proactive voice guidance.
    case mute
    /// Restore voice guidance.
    case unmute
    /// Ask which layby / destination the driver is stopping at.
    case whereStopping
    /// Ask whether the advisory HOS / card budget still allows driving.
    case canIDrive
    /// Ask about named UK tolls on the active route.
    case tollAhead
    /// Ask about the next LEZ / CAZ restriction on the route.
    case nextLez
    /// Ask for remaining ETA.
    case eta
    /// Ask about hazards / closures ahead on the route.
    case hazardAhead
    /// Ask about roadworks / construction ahead.
    case roadworksAhead
    /// Ask about the primary fused predictive-risk advisory.
    case riskAhead
}

/// Matches normalized speech transcripts to ``DriverVoiceCommand`` values.
public enum DriverVoiceCommandPhraseMatcher: Sendable {
    /// Returns the best matching command, or `nil` when unrecognized.
    public static func match(_ transcript: String) -> DriverVoiceCommand? {
        let normalized = normalize(transcript)
        guard !normalized.isEmpty else { return nil }

        let ranked: [(DriverVoiceCommand, [String])] = [
            (.breakNow, [
                "break now",
                "find a layby",
                "find layby",
                "find a rest stop",
                "need a break",
                "i need a break",
            ]),
            (.nextLayby, [
                "next layby",
                "skip this layby",
                "skip layby",
                "layby is full",
                "this layby is full",
                "looks full",
            ]),
            (.unmute, [
                "unmute",
                "voice on",
                "turn voice on",
                "enable voice",
            ]),
            (.mute, [
                "mute",
                "be quiet",
                "silence",
                "voice off",
                "turn voice off",
                "stop talking",
            ]),
            (.whereStopping, [
                "where am i stopping",
                "where am i stopping?",
                "next stop",
                "where is my stop",
                "whats my stop",
                "what's my stop",
                "where am i going",
            ]),
            (.canIDrive, [
                "can i drive",
                "can i drive now",
                "am i legal to drive",
                "am i allowed to drive",
                "can i keep driving",
                "how much drive time left",
            ]),
            (.tollAhead, [
                "any tolls",
                "toll ahead",
                "any tolls ahead",
                "are there tolls",
                "tolls on this route",
                "what tolls",
            ]),
            (.nextLez, [
                "next lez",
                "low emission zone",
                "clean air zone",
                "any caz",
                "any lez",
                "emission zone ahead",
                "ulez ahead",
            ]),
            (.eta, [
                "what's my eta",
                "whats my eta",
                "what is my eta",
                "how long left",
                "how long until i arrive",
                "arrival time",
                "eta",
            ]),
            (.roadworksAhead, [
                "any roadworks",
                "roadworks ahead",
                "any roadworks ahead",
                "construction ahead",
                "any construction",
                "road works ahead",
            ]),
            (.hazardAhead, [
                "any hazards",
                "hazard ahead",
                "any hazards ahead",
                "any closures",
                "closure ahead",
                "road closed ahead",
                "what's ahead",
                "whats ahead",
            ]),
            (.riskAhead, [
                "any risks",
                "what's the risk",
                "whats the risk",
                "what is the risk",
                "traffic risk",
                "risk ahead",
                "any risk ahead",
            ]),
        ]

        var best: (DriverVoiceCommand, Int)?
        for (command, phrases) in ranked {
            for phrase in phrases {
                if normalized == phrase || normalized.contains(phrase) {
                    let score = phrase.count
                    if best == nil || score > best!.1 {
                        best = (command, score)
                    }
                }
            }
        }
        return best?.0
    }

    /// Lowercases, strips punctuation, and collapses whitespace.
    public static func normalize(_ transcript: String) -> String {
        let folded = transcript
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s']", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return folded
    }
}
