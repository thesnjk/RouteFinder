package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.nav.AnnouncementTier
import com.routefinder.fleetdriver.nav.LaneArrow
import com.routefinder.fleetdriver.nav.LaneGuidance
import com.routefinder.fleetdriver.nav.LaneGuidanceSource
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
        assertTrue(spoken.contains("onto High Street"))
    }

    @Test
    fun approachUsesKilometres() {
        val instruction = TurnInstruction(TurnManeuver.RIGHT, "A47", 2000.0, 90.0)
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.APPROACH)
        assertTrue(spoken.contains("1.6 kilometres"))
        assertTrue(spoken.contains("onto A47"))
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

    @Test
    fun preparePrefersLanePhraseFirstWithStreet() {
        val instruction = TurnInstruction(
            TurnManeuver.RIGHT,
            "A1",
            400.0,
            90.0,
            laneGuidance = LaneGuidance(
                lanes = listOf(LaneArrow.STRAIGHT, LaneArrow.RIGHT),
                recommendedIndices = listOf(1),
                source = LaneGuidanceSource.OSM,
            ),
        )
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.PREPARE)
        assertTrue(spoken.startsWith("In 400 metres, use the right lane"))
        assertTrue(spoken.contains("onto A1"))
        assertFalse(spoken.lowercase().contains("turn right"))
    }

    @Test
    fun executeUsesLaneThenManeuverOntoStreet() {
        val instruction = TurnInstruction(
            TurnManeuver.RIGHT,
            "A47",
            120.0,
            90.0,
            laneGuidance = LaneGuidance(
                lanes = listOf(LaneArrow.STRAIGHT, LaneArrow.RIGHT),
                recommendedIndices = listOf(1),
                source = LaneGuidanceSource.OSM,
            ),
        )
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.EXECUTE)
        assertTrue(spoken.startsWith("Use the right lane, then turn right"))
        assertTrue(spoken.contains("onto A47"))
    }

    @Test
    fun prepareUsesContiguousMultiLanePhrase() {
        val instruction = TurnInstruction(
            TurnManeuver.LEFT,
            "M6",
            400.0,
            270.0,
            laneGuidance = LaneGuidance(
                lanes = listOf(LaneArrow.STRAIGHT, LaneArrow.STRAIGHT, LaneArrow.RIGHT),
                recommendedIndices = listOf(0, 1),
                source = LaneGuidanceSource.OSM,
            ),
        )
        val spoken = ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.PREPARE)
        assertTrue(spoken.contains("left two lanes"))
        assertTrue(spoken.contains("onto M6"))
    }
}
