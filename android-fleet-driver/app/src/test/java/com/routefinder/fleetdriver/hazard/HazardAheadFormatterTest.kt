package com.routefinder.fleetdriver.hazard

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HazardAheadFormatterTest {
    @Test
    fun shouldAnnounceInsideThresholdOnce() {
        val announcement = HazardAheadAnnouncement(
            id = "h1",
            type = HazardEventType.CLOSURE,
            distanceRemainingMeters = 2500.0,
            message = "Closure ahead",
            source = "crowd:test",
        )
        assertTrue(HazardAheadFormatter.shouldAnnounce(announcement, null))
        assertFalse(HazardAheadFormatter.shouldAnnounce(announcement, "h1"))
    }

    @Test
    fun promotedHazardsSkipsStaleAndNonAlertable() {
        val now = System.currentTimeMillis()
        val fresh = CrowdReport(
            id = "a",
            latitude = 51.5,
            longitude = -0.1,
            type = HazardEventType.TRAFFIC,
            reporterId = "driver",
            createdAtEpochMs = now - 5 * 60 * 1000L,
        )
        val stale = CrowdReport(
            id = "b",
            latitude = 51.5,
            longitude = -0.1,
            type = HazardEventType.TRAFFIC,
            reporterId = "driver",
            createdAtEpochMs = now - 60 * 60 * 1000L,
        )
        val camera = CrowdReport(
            id = "c",
            latitude = 51.5,
            longitude = -0.1,
            type = HazardEventType.CAMERA,
            reporterId = "driver",
            createdAtEpochMs = now,
        )
        val promoted = HazardAheadFormatter.promotedHazards(listOf(fresh, stale, camera), now)
        assertEquals(1, promoted.size)
        assertEquals("crowd-a", promoted.first().id)
    }

    @Test
    fun nearestAheadPicksClosestClosureOnRoute() {
        val route = listOf(
            LatLon(51.50, -0.10),
            LatLon(51.55, -0.05),
            LatLon(51.60, 0.00),
        )
        val now = System.currentTimeMillis()
        val hazards = listOf(
            HazardEvent(
                id = "far",
                latitude = 51.59,
                longitude = -0.01,
                radiusMeters = 90.0,
                type = HazardEventType.CLOSURE,
                severity = HazardSeverity.HIGH,
                validFromEpochMs = now - 60_000,
                validToEpochMs = now + 3_600_000,
                source = "crowd:a",
            ),
            HazardEvent(
                id = "near",
                latitude = 51.52,
                longitude = -0.08,
                radiusMeters = 90.0,
                type = HazardEventType.CLOSURE,
                severity = HazardSeverity.HIGH,
                validFromEpochMs = now - 60_000,
                validToEpochMs = now + 3_600_000,
                source = "crowd:b",
            ),
        )
        val result = HazardAheadFormatter.nearestAhead(
            hazards = hazards,
            crowdReports = emptyList(),
            route = route,
            currentArcLengthMeters = 0.0,
            nowEpochMs = now,
        )
        assertNotNull(result)
        assertEquals("near", result!!.id)
        assertTrue(result.message.contains("Closure"))
    }

    @Test
    fun nearestAheadNullWithoutRoute() {
        assertNull(
            HazardAheadFormatter.nearestAhead(
                hazards = emptyList(),
                crowdReports = emptyList(),
                route = listOf(LatLon(51.5, -0.1)),
                currentArcLengthMeters = 0.0,
            ),
        )
    }
}
