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
}

class VoiceAssistResponseFormatterTest {
    @Test
    fun canIDriveFormatsYesAndNo() {
        val yes = CanIDriveStatus(
            canDrive = true,
            reason = "Yes",
            remainingContinuousDriveSeconds = 2700.0,
        )
        val spokenYes = VoiceAssistResponseFormatter.canIDrive(yes)
        assertTrue(spokenYes.contains("Yes"))
        assertTrue(spokenYes.contains("45 minutes"))

        val no = CanIDriveStatus(
            canDrive = false,
            reason = "No",
            remainingContinuousDriveSeconds = 0.0,
            usesImportedCard = true,
        )
        assertTrue(VoiceAssistResponseFormatter.canIDrive(no).startsWith("No."))
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
