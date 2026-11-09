package com.routefinder.fleetdriver.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LaneOsmUpgradeTest {
    @Test
    fun detectsHeuristicToOsmUpgrade() {
        val previous = listOf(
            TurnInstruction(
                TurnManeuver.LEFT,
                "A11",
                400.0,
                10.0,
                laneGuidance = LaneGuidance(
                    lanes = listOf(LaneArrow.LEFT, LaneArrow.STRAIGHT),
                    recommendedIndices = listOf(0),
                    source = LaneGuidanceSource.HEURISTIC,
                ),
            ),
        )
        val updated = listOf(
            TurnInstruction(
                TurnManeuver.LEFT,
                "A11",
                400.0,
                10.0,
                laneGuidance = LaneGuidance(
                    lanes = listOf(LaneArrow.LEFT, LaneArrow.STRAIGHT, LaneArrow.RIGHT),
                    recommendedIndices = listOf(0, 1),
                    source = LaneGuidanceSource.OSM,
                ),
            ),
        )
        assertEquals(listOf(0), LaneOsmUpgrade.upgradedManeuverIndices(previous, updated))
    }

    @Test
    fun ignoresAlreadyOsm() {
        val guidance = LaneGuidance(
            lanes = listOf(LaneArrow.RIGHT),
            recommendedIndices = listOf(0),
            source = LaneGuidanceSource.OSM,
        )
        val instructions = listOf(
            TurnInstruction(TurnManeuver.RIGHT, null, 200.0, 0.0, laneGuidance = guidance),
        )
        assertTrue(LaneOsmUpgrade.upgradedManeuverIndices(instructions, instructions).isEmpty())
    }

    @Test
    fun detectsNilToOsmAtIndex() {
        val previous = listOf(
            TurnInstruction(TurnManeuver.STRAIGHT, null, 100.0, 0.0),
            TurnInstruction(TurnManeuver.RIGHT, "A14", 300.0, 90.0),
        )
        val updated = listOf(
            previous[0],
            previous[1].copy(
                laneGuidance = LaneGuidance(
                    lanes = listOf(LaneArrow.RIGHT, LaneArrow.STRAIGHT),
                    recommendedIndices = listOf(0),
                    source = LaneGuidanceSource.OSM,
                ),
            ),
        )
        assertEquals(listOf(1), LaneOsmUpgrade.upgradedManeuverIndices(previous, updated))
    }
}
