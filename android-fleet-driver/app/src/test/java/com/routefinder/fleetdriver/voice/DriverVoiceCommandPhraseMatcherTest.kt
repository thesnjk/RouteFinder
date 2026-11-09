package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.compliance.CanIDriveStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DriverVoiceCommandPhraseMatcherTest {
    @Test
    fun matchesBreakNow() {
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("Break now"))
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("Please find a layby"))
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("I need a break"))
    }

    @Test
    fun matchesNextLayby() {
        assertEquals(DriverVoiceCommand.NEXT_LAYBY, DriverVoiceCommandPhraseMatcher.match("Next layby"))
        assertEquals(DriverVoiceCommand.NEXT_LAYBY, DriverVoiceCommandPhraseMatcher.match("Skip this layby"))
        assertEquals(DriverVoiceCommand.NEXT_LAYBY, DriverVoiceCommandPhraseMatcher.match("Looks full"))
    }

    @Test
    fun matchesMuteUnmute() {
        assertEquals(DriverVoiceCommand.MUTE, DriverVoiceCommandPhraseMatcher.match("Mute"))
        assertEquals(DriverVoiceCommand.MUTE, DriverVoiceCommandPhraseMatcher.match("Be quiet"))
        assertEquals(DriverVoiceCommand.UNMUTE, DriverVoiceCommandPhraseMatcher.match("Unmute"))
        assertEquals(DriverVoiceCommand.UNMUTE, DriverVoiceCommandPhraseMatcher.match("Voice on"))
    }

    @Test
    fun matchesWhereStopping() {
        assertEquals(
            DriverVoiceCommand.WHERE_STOPPING,
            DriverVoiceCommandPhraseMatcher.match("Where am I stopping?"),
        )
        assertEquals(DriverVoiceCommand.WHERE_STOPPING, DriverVoiceCommandPhraseMatcher.match("Next stop"))
    }

    @Test
    fun matchesDomainV2Intents() {
        assertEquals(DriverVoiceCommand.CAN_I_DRIVE, DriverVoiceCommandPhraseMatcher.match("Can I drive now?"))
        assertEquals(DriverVoiceCommand.CAN_I_DRIVE, DriverVoiceCommandPhraseMatcher.match("Am I legal to drive"))
        assertEquals(DriverVoiceCommand.TOLL_AHEAD, DriverVoiceCommandPhraseMatcher.match("Any tolls ahead"))
        assertEquals(DriverVoiceCommand.NEXT_LEZ, DriverVoiceCommandPhraseMatcher.match("Low emission zone"))
        assertEquals(DriverVoiceCommand.ETA, DriverVoiceCommandPhraseMatcher.match("What's my ETA"))
        assertEquals(DriverVoiceCommand.ETA, DriverVoiceCommandPhraseMatcher.match("How long left"))
    }

    @Test
    fun matchesHazardRoadworksRiskIntents() {
        assertEquals(DriverVoiceCommand.HAZARD_AHEAD, DriverVoiceCommandPhraseMatcher.match("Any hazards ahead"))
        assertEquals(DriverVoiceCommand.HAZARD_AHEAD, DriverVoiceCommandPhraseMatcher.match("What's ahead"))
        assertEquals(DriverVoiceCommand.ROADWORKS_AHEAD, DriverVoiceCommandPhraseMatcher.match("Any roadworks"))
        assertEquals(DriverVoiceCommand.ROADWORKS_AHEAD, DriverVoiceCommandPhraseMatcher.match("Construction ahead"))
        assertEquals(DriverVoiceCommand.RISK_AHEAD, DriverVoiceCommandPhraseMatcher.match("What's the risk"))
        assertEquals(DriverVoiceCommand.RISK_AHEAD, DriverVoiceCommandPhraseMatcher.match("Traffic risk"))
    }

    @Test
    fun unrecognizedReturnsNull() {
        assertNull(DriverVoiceCommandPhraseMatcher.match(""))
        assertNull(DriverVoiceCommandPhraseMatcher.match("what's the weather"))
        assertNull(DriverVoiceCommandPhraseMatcher.match("reroute me"))
    }

    @Test
    fun unmuteWinsOverMuteSubstring() {
        assertEquals(DriverVoiceCommand.UNMUTE, DriverVoiceCommandPhraseMatcher.match("please unmute"))
    }

    @Test
    fun matchesBookParkingPhrases() {
        assertEquals(DriverVoiceCommand.BOOK_PARKING, DriverVoiceCommandPhraseMatcher.match("Book parking"))
        assertEquals(
            DriverVoiceCommand.BOOK_PARKING,
            DriverVoiceCommandPhraseMatcher.match("Reserve parking please"),
        )
        assertEquals(
            DriverVoiceCommand.BOOK_PARKING,
            DriverVoiceCommandPhraseMatcher.match("Book a truck stop"),
        )
        assertEquals(
            DriverVoiceCommand.BOOK_PARKING,
            DriverVoiceCommandPhraseMatcher.match("Book a layby bay"),
        )
        assertEquals(
            DriverVoiceCommand.NEXT_LAYBY,
            DriverVoiceCommandPhraseMatcher.match("This layby is full"),
        )
    }

    @Test
    fun matchesWhichLanePhrases() {
        assertEquals(DriverVoiceCommand.WHICH_LANE, DriverVoiceCommandPhraseMatcher.match("Which lane"))
        assertEquals(
            DriverVoiceCommand.WHICH_LANE,
            DriverVoiceCommandPhraseMatcher.match("Which lane should I take"),
        )
        assertEquals(DriverVoiceCommand.WHICH_LANE, DriverVoiceCommandPhraseMatcher.match("Lane guidance"))
        assertEquals(
            DriverVoiceCommand.WHICH_LANE,
            DriverVoiceCommandPhraseMatcher.match("What lane am I in"),
        )
    }

    @Test
    fun matchesAvoidTollsDistinctFromTollAhead() {
        assertEquals(DriverVoiceCommand.AVOID_TOLLS, DriverVoiceCommandPhraseMatcher.match("Avoid tolls"))
        assertEquals(
            DriverVoiceCommand.AVOID_TOLLS,
            DriverVoiceCommandPhraseMatcher.match("Avoid tolls and replan"),
        )
        assertEquals(DriverVoiceCommand.AVOID_TOLLS, DriverVoiceCommandPhraseMatcher.match("Skip tolls"))
        assertEquals(
            DriverVoiceCommand.AVOID_TOLLS,
            DriverVoiceCommandPhraseMatcher.match("Reroute without tolls"),
        )
        assertEquals(DriverVoiceCommand.TOLL_AHEAD, DriverVoiceCommandPhraseMatcher.match("Any tolls ahead"))
    }
}

class VoiceAssistResponseFormatterTest {
    @Test
    fun canIDriveFormatsYesAndNo() {
        val yes = CanIDriveStatus(
            canDrive = true,
            reason = "Yes",
            remainingContinuousDriveSeconds = 2700.0,
            remainingDailyDriveSeconds = 7200.0,
            remainingWeeklyDriveSeconds = 36_000.0,
        )
        val spokenYes = VoiceAssistResponseFormatter.canIDrive(yes)
        assertTrue(spokenYes.contains("Yes"))
        assertTrue(spokenYes.contains("45 minutes"))
        assertTrue(spokenYes.contains("continuous"))
        assertTrue(spokenYes.contains("daily"))
        assertTrue(spokenYes.contains("weekly"))

        val noContinuous = CanIDriveStatus(
            canDrive = false,
            reason = "No",
            remainingContinuousDriveSeconds = 0.0,
            remainingDailyDriveSeconds = 1000.0,
            remainingWeeklyDriveSeconds = 1000.0,
            usesImportedCard = true,
        )
        assertTrue(VoiceAssistResponseFormatter.canIDrive(noContinuous).contains("Continuous"))
        assertTrue(
            VoiceAssistResponseFormatter.canIDrive(
                CanIDriveStatus(
                    canDrive = false,
                    reason = "No",
                    remainingContinuousDriveSeconds = 100.0,
                    remainingDailyDriveSeconds = 0.0,
                    remainingWeeklyDriveSeconds = 1000.0,
                ),
            ).contains("Daily"),
        )
        assertTrue(
            VoiceAssistResponseFormatter.canIDrive(
                CanIDriveStatus(
                    canDrive = false,
                    reason = "No",
                    remainingContinuousDriveSeconds = 100.0,
                    remainingDailyDriveSeconds = 100.0,
                    remainingWeeklyDriveSeconds = 0.0,
                ),
            ).contains("Weekly"),
        )
        assertTrue(VoiceAssistResponseFormatter.canIDrive(null).contains("unavailable"))
    }

    @Test
    fun tollAheadNextLezAndEta() {
        val toll = VoiceAssistResponseFormatter.tollAhead(
            tollName = "Dartford Crossing",
            distanceMeters = 4200.0,
            costLabel = "~£6.00",
            routeSummary = null,
        )
        assertTrue(toll.contains("Dartford"))
        assertTrue(toll.contains("kilometres") || toll.contains("metres"))
        assertEquals(
            "No named tolls on this route.",
            VoiceAssistResponseFormatter.tollAhead(null, null, null, null),
        )
        assertTrue(
            VoiceAssistResponseFormatter.nextLez("London ULEZ", null).contains("London ULEZ"),
        )
        assertTrue(VoiceAssistResponseFormatter.eta(3720.0).contains("hours"))
        assertEquals("ETA is unavailable.", VoiceAssistResponseFormatter.eta(null))
    }

    @Test
    fun bookParkingFormatsLabelTierAndNone() {
        val withTier = VoiceAssistResponseFormatter.bookParking("A14 Services", "Limited")
        assertTrue(withTier.contains("A14 Services"))
        assertTrue(withTier.contains("Limited"))
        assertTrue(withTier.contains("Partner site"))
        assertTrue(VoiceAssistResponseFormatter.bookParking("  ", null).contains("Ahead parking"))
        assertTrue(VoiceAssistResponseFormatter.BOOK_PARKING_NONE.contains("No ahead parking"))
    }

    @Test
    fun whichLaneFormatsGuidanceRoadDistanceAndNone() {
        val spoken = VoiceAssistResponseFormatter.whichLane("Use the left lane", "A14", 400.0)
        assertTrue(spoken.contains("Use the left lane"))
        assertTrue(spoken.contains("onto A14"))
        assertTrue(spoken.contains("metres") || spoken.contains("kilometres"))
        assertEquals("No lane guidance right now.", VoiceAssistResponseFormatter.WHICH_LANE_NONE)
        assertEquals(
            VoiceAssistResponseFormatter.WHICH_LANE_NONE,
            VoiceAssistResponseFormatter.whichLane(null, "A14", 100.0),
        )
    }

    @Test
    fun avoidTollsFormatsStartedAndAlreadyAvoiding() {
        val started = VoiceAssistResponseFormatter.avoidTolls(started = true)
        assertTrue(started.contains("Avoiding tolls"))
        assertTrue(started.contains("Indicative only"))
        assertTrue(
            VoiceAssistResponseFormatter.avoidTolls(started = false).contains("Already avoiding tolls"),
        )
    }

    @Test
    fun hazardRoadworksRiskEmptyHonesty() {
        assertEquals(
            "No hazards flagged ahead.",
            VoiceAssistResponseFormatter.hazardAhead(null, null),
        )
        assertEquals(
            "No roadworks flagged ahead.",
            VoiceAssistResponseFormatter.roadworksAhead(null, null),
        )
        assertTrue(
            VoiceAssistResponseFormatter.roadworksAhead("Roadworks on A11", 2500.0).contains("A11"),
        )
        assertEquals(
            "No predictive risks flagged ahead.",
            VoiceAssistResponseFormatter.riskAhead(null),
        )
        assertTrue(
            VoiceAssistResponseFormatter.riskAhead("Slow traffic ahead").contains("Slow traffic"),
        )
    }
}
