package com.routefinder.fleetdriver.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TurnLanesParserTest {
    @Test
    fun parsesLeftThroughRight() {
        val guidance = TurnLanesParser.parse("left|through|right")
        assertNotNull(guidance)
        assertEquals(3, guidance!!.lanes.size)
        assertEquals(LaneArrow.LEFT, guidance.lanes[0])
        assertEquals(LaneArrow.STRAIGHT, guidance.lanes[1])
        assertEquals(LaneArrow.RIGHT, guidance.lanes[2])
        assertEquals(LaneGuidanceSource.OSM, guidance.source)
    }

    @Test
    fun recommendsMatchingLaneForLeftManeuver() {
        val guidance = TurnLanesParser.parse("left|through|right", forManeuver = TurnManeuver.LEFT)
        assertNotNull(guidance)
        assertEquals(listOf(0), guidance!!.recommendedIndices)
        assertTrue(guidance.guidanceText.contains("left", ignoreCase = true))
    }

    @Test
    fun heuristicForRightUsesRightmostLane() {
        val guidance = TurnLanesParser.heuristic(TurnManeuver.RIGHT, laneCount = 3)
        assertEquals(LaneGuidanceSource.HEURISTIC, guidance.source)
        assertEquals(listOf(2), guidance.recommendedIndices)
        assertEquals(LaneArrow.RIGHT, guidance.lanes[2])
        assertTrue(guidance.guidanceText.lowercase().contains("right") || guidance.guidanceText.contains("3"))
    }

    @Test
    fun guidanceTextForSingleRecommendedLane() {
        val guidance = LaneGuidance(
            lanes = listOf(LaneArrow.LEFT, LaneArrow.STRAIGHT, LaneArrow.RIGHT),
            recommendedIndices = listOf(0),
            source = LaneGuidanceSource.HEURISTIC,
        )
        assertEquals("Use the left lane", guidance.guidanceText)
    }

    @Test
    fun spokenLanePhraseUsesLeftTwoLanesWhenContiguous() {
        val guidance = LaneGuidance(
            lanes = listOf(LaneArrow.STRAIGHT, LaneArrow.STRAIGHT, LaneArrow.RIGHT),
            recommendedIndices = listOf(0, 1),
            source = LaneGuidanceSource.OSM,
        )
        assertEquals("Use the left two lanes", guidance.spokenLanePhrase())
        assertEquals(guidance.spokenLanePhrase(), guidance.guidanceText)
    }

    @Test
    fun spokenLanePhraseUsesRightTwoLanesWhenContiguous() {
        val guidance = LaneGuidance(
            lanes = listOf(LaneArrow.STRAIGHT, LaneArrow.RIGHT, LaneArrow.RIGHT),
            recommendedIndices = listOf(1, 2),
            source = LaneGuidanceSource.OSM,
        )
        assertEquals("Use the right two lanes", guidance.spokenLanePhrase())
    }

    @Test
    fun spokenLanePhraseListsNonContiguousLanes() {
        val guidance = LaneGuidance(
            lanes = listOf(LaneArrow.LEFT, LaneArrow.STRAIGHT, LaneArrow.RIGHT),
            recommendedIndices = listOf(0, 2),
            source = LaneGuidanceSource.OSM,
        )
        assertEquals("Use lanes 1 and 3", guidance.spokenLanePhrase())
    }
}
