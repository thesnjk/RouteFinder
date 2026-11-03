package com.routefinder.fleetdriver.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DriverVoiceCommandPhraseMatcherTest {
    @Test
    fun matchesBreakNowPhrases() {
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("Break now"))
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("Please find a layby"))
        assertEquals(DriverVoiceCommand.BREAK_NOW, DriverVoiceCommandPhraseMatcher.match("I need a break"))
    }

    @Test
    fun matchesNextLaybyPhrases() {
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
    fun responseFormatterBreakNowAndWhereStopping() {
        assertTrue(VoiceAssistResponseFormatter.breakNow(null).contains("No laybys"))
        assertTrue(
            VoiceAssistResponseFormatter.breakNow("Layby ahead: A11 (~3 km)").contains("A11"),
        )
        assertTrue(
            VoiceAssistResponseFormatter.whereStopping(null, "Norwich Depot").contains("Norwich Depot"),
        )
        assertEquals(
            "No layby planned on this route.",
            VoiceAssistResponseFormatter.whereStopping(null, null),
        )
    }
}
