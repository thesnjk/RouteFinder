import Contracts
import Testing

struct DriverVoiceCommandPhraseMatcherTests {
    @Test func matchesBreakNowPhrases() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Break now") == .breakNow)
        #expect(DriverVoiceCommandPhraseMatcher.match("Please find a layby") == .breakNow)
        #expect(DriverVoiceCommandPhraseMatcher.match("I need a break") == .breakNow)
    }

    @Test func matchesNextLaybyPhrases() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Next layby") == .nextLayby)
        #expect(DriverVoiceCommandPhraseMatcher.match("Skip this layby") == .nextLayby)
        #expect(DriverVoiceCommandPhraseMatcher.match("Looks full") == .nextLayby)
    }

    @Test func matchesMuteUnmute() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Mute") == .mute)
        #expect(DriverVoiceCommandPhraseMatcher.match("Be quiet") == .mute)
        #expect(DriverVoiceCommandPhraseMatcher.match("Unmute") == .unmute)
        #expect(DriverVoiceCommandPhraseMatcher.match("Voice on") == .unmute)
    }

    @Test func matchesWhereStopping() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Where am I stopping?") == .whereStopping)
        #expect(DriverVoiceCommandPhraseMatcher.match("Next stop") == .whereStopping)
    }

    @Test func unrecognizedReturnsNil() {
        #expect(DriverVoiceCommandPhraseMatcher.match("") == nil)
        #expect(DriverVoiceCommandPhraseMatcher.match("what's the weather") == nil)
        #expect(DriverVoiceCommandPhraseMatcher.match("reroute me") == nil)
    }

    @Test func unmuteWinsOverMuteSubstring() {
        // "unmute" contains "mute" — longest / preferred phrase should win.
        #expect(DriverVoiceCommandPhraseMatcher.match("please unmute") == .unmute)
    }
}

struct VoiceAssistResponseFormatterTests {
    @Test func breakNowUsesLaybyPrompt() {
        let advisory = LaybyAdvisory(
            stop: LaybyStop(
                id: "l1",
                coordinate: Coordinate(latitude: 52.0, longitude: 0.1),
                label: "A11 Layby"
            ),
            distanceRemainingMeters: 3200,
            estimatedArrivalSeconds: 180
        )
        let spoken = VoiceAssistResponseFormatter.breakNow(advisory: advisory)
        #expect(spoken.contains("A11 Layby"))
        #expect(VoiceAssistResponseFormatter.breakNow(advisory: nil).contains("No laybys"))
    }

    @Test func whereStoppingFallsBackToDestination() {
        #expect(
            VoiceAssistResponseFormatter.whereStopping(
                advisory: nil,
                destinationLabel: "Norwich Depot"
            ).contains("Norwich Depot")
        )
        #expect(
            VoiceAssistResponseFormatter.whereStopping(
                advisory: nil,
                destinationLabel: nil
            ) == "No layby planned on this route."
        )
    }
}
