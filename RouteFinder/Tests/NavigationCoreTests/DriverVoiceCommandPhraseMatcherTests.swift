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

    @Test func matchesHazardRoadworksRiskIntents() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Any hazards ahead") == .hazardAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("What's ahead") == .hazardAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("Any roadworks") == .roadworksAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("Construction ahead") == .roadworksAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("What's the risk") == .riskAhead)
        #expect(DriverVoiceCommandPhraseMatcher.match("Traffic risk") == .riskAhead)
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

    @Test func matchesBookParkingPhrases() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Book parking") == .bookParking)
        #expect(DriverVoiceCommandPhraseMatcher.match("Reserve parking please") == .bookParking)
        #expect(DriverVoiceCommandPhraseMatcher.match("Book a truck stop") == .bookParking)
        #expect(DriverVoiceCommandPhraseMatcher.match("Book a layby bay") == .bookParking)
        // Distinct from nextLayby “layby is full”.
        #expect(DriverVoiceCommandPhraseMatcher.match("This layby is full") == .nextLayby)
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

    @Test func bookParkingFormatsLabelTierAndNone() {
        let withTier = VoiceAssistResponseFormatter.bookParking(label: "A14 Services", tier: .limited)
        #expect(withTier.contains("A14 Services"))
        #expect(withTier.contains("Limited"))
        #expect(withTier.contains("Partner site"))
        #expect(
            VoiceAssistResponseFormatter.bookParking(label: "  ", tier: nil).contains("Ahead parking")
        )
        #expect(VoiceAssistResponseFormatter.bookParkingNone.contains("No ahead parking"))
    }

    @Test func hazardRoadworksRiskEmptyHonesty() {
        #expect(VoiceAssistResponseFormatter.hazardAhead(announcement: nil) == "No hazards flagged ahead.")
        #expect(
            VoiceAssistResponseFormatter.roadworksAhead(label: nil, remainingMeters: nil)
                == "No roadworks flagged ahead."
        )
        #expect(
            VoiceAssistResponseFormatter.roadworksAhead(
                label: "Roadworks: A11 works",
                remainingMeters: 2500
            ).contains("A11")
        )
        #expect(VoiceAssistResponseFormatter.riskAhead(spokenPrompt: nil) == "No predictive risks flagged ahead.")
        #expect(VoiceAssistResponseFormatter.riskAhead(spokenPrompt: "Slow traffic ahead").contains("Slow traffic"))
    }
}
