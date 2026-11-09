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

    @Test func matchesDomainV2Intents() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Can I drive now?") == .canIDrive)
        #expect(DriverVoiceCommandPhraseMatcher.match("Am I legal to drive") == .canIDrive)
        #expect(DriverVoiceCommandPhraseMatcher.match("Any tolls ahead") == .tollAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("Low emission zone") == .nextLez)
        #expect(DriverVoiceCommandPhraseMatcher.match("What's my ETA") == .eta)
        #expect(DriverVoiceCommandPhraseMatcher.match("How long left") == .eta)
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

    @Test func canIDriveFormatsYesAndNo() {
        let yes = CanIDriveStatus(
            canDrive: true,
            reason: "Yes",
            remainingContinuousDriveSeconds: 2700,
            usesImportedCard: false
        )
        #expect(VoiceAssistResponseFormatter.canIDrive(status: yes).contains("Yes"))
        #expect(VoiceAssistResponseFormatter.canIDrive(status: yes).contains("45 minutes"))

        let no = CanIDriveStatus(
            canDrive: false,
            reason: "No",
            remainingContinuousDriveSeconds: 0,
            usesImportedCard: true
        )
        #expect(VoiceAssistResponseFormatter.canIDrive(status: no).hasPrefix("No."))
        #expect(VoiceAssistResponseFormatter.canIDrive(status: nil).contains("unavailable"))
    }

    @Test func tollAheadAndNextLezAndEta() {
        let toll = VoiceAssistResponseFormatter.tollAhead(
            tollName: "Dartford Crossing",
            distanceMeters: 4200,
            costLabel: "~£6.00",
            routeSummary: nil
        )
        #expect(toll.contains("Dartford"))
        #expect(toll.contains("kilometres") || toll.contains("metres"))
        #expect(VoiceAssistResponseFormatter.tollAhead(
            tollName: nil,
            distanceMeters: nil,
            costLabel: nil,
            routeSummary: nil
        ) == "No named tolls on this route.")

        #expect(
            VoiceAssistResponseFormatter.nextLez(label: "London ULEZ", message: nil)
                .contains("London ULEZ")
        )
        #expect(VoiceAssistResponseFormatter.eta(remainingSeconds: 3720).contains("hours"))
        #expect(VoiceAssistResponseFormatter.eta(remainingSeconds: nil) == "ETA is unavailable.")
    }
}
