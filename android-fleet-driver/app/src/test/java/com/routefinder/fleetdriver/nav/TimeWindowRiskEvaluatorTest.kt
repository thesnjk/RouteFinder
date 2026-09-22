package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.fleet.FleetTripStop
import com.routefinder.fleetdriver.fleet.StopTimeWindow
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TimeWindowRiskEvaluatorTest {
    @Test
    fun advisory_flagsLateEtaAgainstLatestArrival() {
        val stopId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        val now = Instant.parse("2026-09-21T12:00:00Z")
        val latest = Instant.parse("2026-09-21T12:30:00Z")
        val result = TimeWindowRiskEvaluator.advisory(
            windows = listOf(
                StopTimeWindow(stopId = stopId, latestArrival = latest.toString()),
            ),
            stops = listOf(
                FleetTripStop(stopId, 0, "Manchester Depot", 53.48, -2.24, "destination"),
            ),
            // 2h ETA → arrive 14:00, 90 min late (> 15 min slack)
            physicsEtaSeconds = 2 * 3_600.0,
            now = now,
        )
        assertNotNull(result)
        assertTrue(result!!.message.contains("Manchester Depot"))
        assertTrue(result.message.contains("late"))
        assertTrue(result.distanceMeters >= 500)
    }

    @Test
    fun advisory_nullWhenWithinSlack() {
        val stopId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        val now = Instant.parse("2026-09-21T12:00:00Z")
        val latest = Instant.parse("2026-09-21T13:00:00Z")
        val result = TimeWindowRiskEvaluator.advisory(
            windows = listOf(StopTimeWindow(stopId, latestArrival = latest.toString())),
            stops = listOf(FleetTripStop(stopId, 0, "Port", 51.95, 1.35, "destination")),
            physicsEtaSeconds = 50 * 60.0,
            now = now,
        )
        assertNull(result)
    }

    @Test
    fun parseInstant_readsIso8601() {
        assertEquals(
            Instant.parse("2026-09-21T12:00:00Z"),
            TimeWindowRiskEvaluator.parseInstant("2026-09-21T12:00:00Z"),
        )
        assertNull(TimeWindowRiskEvaluator.parseInstant("not-a-date"))
    }
}
