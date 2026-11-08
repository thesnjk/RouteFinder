package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LiveTrafficHazardSamplerTest {
    @Test
    fun shouldPollRespectsInterval() {
        val now = 1_000_000L
        assertTrue(LiveTrafficHazardSampler.shouldPoll(lastSampleMs = null, nowMs = now))
        assertFalse(
            LiveTrafficHazardSampler.shouldPoll(
                lastSampleMs = now - 10_000L,
                nowMs = now,
            ),
        )
        assertTrue(
            LiveTrafficHazardSampler.shouldPoll(
                lastSampleMs = now - LiveTrafficHazardSampler.POLL_INTERVAL_MS,
                nowMs = now,
            ),
        )
    }

    @Test
    fun samplePointsAheadReturnsIncreasingArcLengths() {
        val route = listOf(
            LatLon(51.50, -0.10),
            LatLon(51.55, -0.05),
            LatLon(51.60, 0.00),
        )
        val points = LiveTrafficHazardSampler.samplePointsAhead(
            route = route,
            currentArcLengthMeters = 1_000.0,
            offsetsMeters = listOf(2_000.0, 5_000.0),
        )
        assertEquals(2, points.size)
        assertEquals(3_000.0, points[0].second, 0.01)
        assertEquals(6_000.0, points[1].second, 0.01)
    }

    @Test
    fun hazardHitForRoadClosed() {
        val sample = LatLon(51.5, -0.1)
        val hit = LiveTrafficHazardSampler.hazardHit(
            flow = LiveTrafficHazardSampler.FlowSample(
                currentSpeedKmh = 40.0,
                freeFlowSpeedKmh = 90.0,
                roadClosed = true,
            ),
            sample = sample,
            arcLengthMeters = 5_000.0,
            currentArcLengthMeters = 1_000.0,
        )
        assertNotNull(hit)
        assertTrue(hit!!.isRoadClosed)
        assertTrue(hit.severe)
        assertTrue(hit.message.contains("closed", ignoreCase = true))
        assertEquals(4_000.0, hit.remainingMeters, 0.01)
    }

    @Test
    fun hazardHitForStandstill() {
        val hit = LiveTrafficHazardSampler.hazardHit(
            flow = LiveTrafficHazardSampler.FlowSample(
                currentSpeedKmh = 0.0,
                freeFlowSpeedKmh = 90.0,
                roadClosed = false,
            ),
            sample = LatLon(51.5, -0.1),
            arcLengthMeters = 5_000.0,
            currentArcLengthMeters = 2_000.0,
        )
        assertNotNull(hit)
        assertFalse(hit!!.isRoadClosed)
        assertTrue(hit.message.contains("traffic", ignoreCase = true))
        assertEquals(3_000.0, hit.remainingMeters, 0.01)
    }

    @Test
    fun hazardHitSkipsNonWorthyFlow() {
        val hit = LiveTrafficHazardSampler.hazardHit(
            flow = LiveTrafficHazardSampler.FlowSample(
                currentSpeedKmh = 70.0,
                freeFlowSpeedKmh = 90.0,
                roadClosed = false,
            ),
            sample = LatLon(51.5, -0.1),
            arcLengthMeters = 5_000.0,
            currentArcLengthMeters = 1_000.0,
        )
        assertNull(hit)
    }

    @Test
    fun nearestHitPicksClosestRemaining() {
        val far = LiveTrafficHazardSampler.Hit(
            id = "far",
            latitude = 51.6,
            longitude = 0.0,
            arcLengthAlongRouteMeters = 8_000.0,
            isRoadClosed = false,
            message = "far",
            remainingMeters = 6_000.0,
            severe = false,
        )
        val near = LiveTrafficHazardSampler.Hit(
            id = "near",
            latitude = 51.5,
            longitude = -0.1,
            arcLengthAlongRouteMeters = 4_000.0,
            isRoadClosed = true,
            message = "near",
            remainingMeters = 2_000.0,
            severe = true,
        )
        assertEquals("near", LiveTrafficHazardSampler.nearestHit(listOf(far, near))?.id)
    }
}
