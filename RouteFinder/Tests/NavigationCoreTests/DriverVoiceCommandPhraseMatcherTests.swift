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

    @Test func matchesWhichLanePhrases() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Which lane") == .whichLane)
        #expect(DriverVoiceCommandPhraseMatcher.match("Which lane should I take") == .whichLane)
        #expect(DriverVoiceCommandPhraseMatcher.match("Lane guidance") == .whichLane)
        #expect(DriverVoiceCommandPhraseMatcher.match("What lane am I in") == .whichLane)
    }

    @Test func matchesAvoidTollsDistinctFromTollAhead() {
        #expect(DriverVoiceCommandPhraseMatcher.match("Avoid tolls") == .avoidTolls)
        #expect(DriverVoiceCommandPhraseMatcher.match("Avoid tolls and replan") == .avoidTolls)
        #expect(DriverVoiceCommandPhraseMatcher.match("Skip tolls") == .avoidTolls)
        #expect(DriverVoiceCommandPhraseMatcher.match("Reroute without tolls") == .avoidTolls)
        #expect(DriverVoiceCommandPhraseMatcher.match("Any tolls ahead") == .tollAhead)
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
            remainingDailyDriveSeconds: 7200,
            remainingWeeklyDriveSeconds: 36_000,
            usesImportedCard: false
        )
        let spokenYes = VoiceAssistResponseFormatter.canIDrive(status: yes)
        #expect(spokenYes.contains("Yes"))
        #expect(spokenYes.contains("45 minutes"))
        #expect(spokenYes.contains("continuous"))
        #expect(spokenYes.contains("daily"))
        #expect(spokenYes.contains("weekly"))

        let noContinuous = CanIDriveStatus(
            canDrive: false,
            reason: "No",
            remainingContinuousDriveSeconds: 0,
            remainingDailyDriveSeconds: 1000,
            remainingWeeklyDriveSeconds: 1000,
            usesImportedCard: true
        )
        #expect(VoiceAssistResponseFormatter.canIDrive(status: noContinuous).contains("Continuous"))
        #expect(
            VoiceAssistResponseFormatter.canIDrive(
                status: CanIDriveStatus(
                    canDrive: false,
                    reason: "No",
                    remainingContinuousDriveSeconds: 100,
                    remainingDailyDriveSeconds: 0,
                    remainingWeeklyDriveSeconds: 1000,
                    usesImportedCard: false
                )
            ).contains("Daily")
        )
        #expect(
            VoiceAssistResponseFormatter.canIDrive(
                status: CanIDriveStatus(
                    canDrive: false,
                    reason: "No",
                    remainingContinuousDriveSeconds: 100,
                    remainingDailyDriveSeconds: 100,
                    remainingWeeklyDriveSeconds: 0,
                    usesImportedCard: false
                )
            ).contains("Weekly")
        )
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

    @Test func whichLaneFormatsGuidanceRoadDistanceAndNone() {
        let spoken = VoiceAssistResponseFormatter.whichLane(
            guidanceText: "Use the left lane",
            roadName: "A14",
            distanceMeters: 400
        )
        #expect(spoken.contains("Use the left lane"))
        #expect(spoken.contains("onto A14"))
        #expect(spoken.contains("metres") || spoken.contains("kilometres"))
        #expect(VoiceAssistResponseFormatter.whichLaneNone == "No lane guidance right now.")
        #expect(
            VoiceAssistResponseFormatter.whichLane(
                guidanceText: nil,
                roadName: "A14",
                distanceMeters: 100
            ) == VoiceAssistResponseFormatter.whichLaneNone
        )
    }

    @Test func avoidTollsFormatsStartedAndAlreadyAvoiding() {
        let started = VoiceAssistResponseFormatter.avoidTolls(started: true)
        #expect(started.contains("Avoiding tolls"))
        #expect(started.contains("Indicative only"))
        #expect(
            VoiceAssistResponseFormatter.avoidTolls(started: false)
                .contains("Already avoiding tolls")
        )
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
