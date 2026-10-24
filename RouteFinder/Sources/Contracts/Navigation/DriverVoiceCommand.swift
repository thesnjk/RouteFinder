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
