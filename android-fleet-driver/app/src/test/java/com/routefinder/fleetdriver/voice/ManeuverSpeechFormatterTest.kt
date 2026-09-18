package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.nav.AnnouncementTier
import com.routefinder.fleetdriver.nav.TurnInstruction
import com.routefinder.fleetdriver.nav.TurnManeuver
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ManeuverSpeechFormatterTest {
    @Test
    fun prepareUsesMetres() {
        val instruction = TurnInstruction(TurnManeuver.LEFT, "High Street", 250.0, 270.0)
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.PREPARE)
        assertTrue(spoken.contains("400 metres"))
        assertTrue(spoken.lowercase().contains("left"))
    }

    @Test
    fun approachUsesKilometres() {
        val instruction = TurnInstruction(TurnManeuver.RIGHT, "A47", 2000.0, 90.0)
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.APPROACH)
        assertTrue(spoken.contains("1.6 kilometres"))
    }

    @Test
    fun suppressesStraight() {
        assertTrue(
            ManeuverSpeechFormatter.shouldSuppressVoice(TurnManeuver.STRAIGHT, AnnouncementTier.EXECUTE),
        )
        assertFalse(
            ManeuverSpeechFormatter.shouldSuppressVoice(TurnManeuver.LEFT, AnnouncementTier.EXECUTE),
        )
    }
}
