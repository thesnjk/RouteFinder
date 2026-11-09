package com.routefinder.fleetdriver.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OverpassLaneGuidanceClientTest {
    private val fixture = """
        {
          "elements": [
            {
              "type": "way",
              "id": 1,
              "tags": {
                "destination:lanes": "A1|A2|A3"
              }
            },
            {
              "type": "way",
              "id": 2,
              "tags": {
                "turn:lanes:forward": "left|through"
              }
            },
            {
              "type": "way",
              "id": 3,
              "tags": {
                "turn:lanes": "left|through|right|through;right"
              }
            }
          ]
        }
    """.trimIndent()

    @Test
    fun richestTagPrefersTurnLanesOverForwardAndDestination() {
        val tagMaps = OverpassLaneGuidanceClient.tagMapsFromOverpassJson(fixture)
        assertEquals(3, tagMaps.size)
        val tag = OverpassLaneGuidanceClient.richestTurnLanesTag(tagMaps)
        assertEquals("left|through|right|through;right", tag)
    }

    @Test
    fun parseGuidanceFromOverpassJsonSelectsRecommendedLane() {
        val guidance = OverpassLaneGuidanceClient.parseGuidanceFromOverpassJson(
            fixture,
            maneuver = TurnManeuver.LEFT,
        )
        assertNotNull(guidance)
        assertEquals(LaneGuidanceSource.OSM, guidance!!.source)
        assertEquals(4, guidance.lanes.size)
        assertEquals(listOf(0), guidance.recommendedIndices)
        assertTrue(guidance.guidanceText.contains("left", ignoreCase = true))
    }

    @Test
    fun emptyElementsYieldNullGuidance() {
        val empty = """{"elements":[]}"""
        assertNull(OverpassLaneGuidanceClient.richestTurnLanesTag(
            OverpassLaneGuidanceClient.tagMapsFromOverpassJson(empty),
        ))
        assertNull(OverpassLaneGuidanceClient.parseGuidanceFromOverpassJson(empty))
    }

    @Test
    fun forwardTagWinsWhenNoTurnLanes() {
        val json = """
            {
              "elements": [
                {"type":"way","id":1,"tags":{"turn:lanes:backward":"right|through"}},
                {"type":"way","id":2,"tags":{"turn:lanes:forward":"left|through|right"}}
              ]
            }
        """.trimIndent()
        val tag = OverpassLaneGuidanceClient.richestTurnLanesTag(
            OverpassLaneGuidanceClient.tagMapsFromOverpassJson(json),
        )
        assertEquals("left|through|right", tag)
    }

    @Test
    fun shouldQueryOverpassSkipsStraightArriveDepart() {
        assertTrue(
            OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 0,
                arcMeters = 0.0,
                maneuver = TurnManeuver.LEFT,
            ),
        )
        assertTrue(
            !OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 0,
                arcMeters = 0.0,
                maneuver = TurnManeuver.STRAIGHT,
            ),
        )
        assertTrue(
            !OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 0,
                arcMeters = 0.0,
                maneuver = TurnManeuver.ARRIVE,
            ),
        )
        assertTrue(
            !OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 0,
                arcMeters = 0.0,
                maneuver = TurnManeuver.DEPART,
            ),
        )
    }

    @Test
    fun shouldQueryOverpassRespectsCapAndArc() {
        assertEquals(12, OverpassLaneGuidanceClient.MAX_MANEUVERS_PER_ROUTE)
        assertEquals(50_000.0, OverpassLaneGuidanceClient.MAX_OVERPASS_DISTANCE_METERS, 0.01)
        assertTrue(
            !OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 12,
                arcMeters = 0.0,
                maneuver = TurnManeuver.RIGHT,
            ),
        )
        assertTrue(
            OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 11,
                arcMeters = 50_000.0,
                maneuver = TurnManeuver.RIGHT,
            ),
        )
        assertTrue(
            !OverpassLaneGuidanceClient.shouldQueryOverpass(
                fetchesSoFar = 0,
                arcMeters = 50_000.1,
                maneuver = TurnManeuver.RIGHT,
            ),
        )
    }
}
