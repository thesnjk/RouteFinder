package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LaybyAlertFormatterTest {
    private fun advisory(
        id: String = "layby-1",
        name: String = "M1 J15",
        remainingMeters: Double = 4_000.0,
    ): LaybyAdvisoryEngine.Advisory {
        val prior = LaybyOccupancyPrior.forHour(12)
        return LaybyAdvisoryEngine.Advisory(
            site = LaybyAdvisoryEngine.Site(id, name, LatLon(52.0, -1.0)),
            remainingMeters = remainingMeters,
            message = "Layby ahead: $name",
            tier = ParkingAvailabilityTier.fromOccupancyPrior(prior),
            occupancyPrior = prior,
        )
    }

    @Test
    fun shouldAnnounceInsideThresholdOnce() {
        val a = advisory(remainingMeters = 4_000.0)
        assertTrue(
            LaybyAlertFormatter.shouldAnnounce(
                advisory = a,
                lastAnnouncedLaybyId = null,
                alertDistanceMeters = 5_000.0,
            ),
        )
        assertFalse(
            LaybyAlertFormatter.shouldAnnounce(
                advisory = a,
                lastAnnouncedLaybyId = "layby-1",
                alertDistanceMeters = 5_000.0,
            ),
        )
    }

    @Test
    fun shouldNotAnnounceOutsideThreshold() {
        val a = advisory(id = "layby-2", remainingMeters = 8_000.0)
        assertFalse(
            LaybyAlertFormatter.shouldAnnounce(
                advisory = a,
                lastAnnouncedLaybyId = null,
                alertDistanceMeters = 5_000.0,
            ),
        )
    }

    @Test
    fun spokenPromptIncludesLabelAndETA() {
        val prompt = LaybyAlertFormatter.spokenPrompt(
            advisory("layby-3", "Northbound layby", 2_000.0),
            estimatedArrivalSeconds = 120.0,
        )
        assertTrue(prompt.contains("Northbound layby"))
        assertTrue(prompt.contains("Layby ahead"))
        assertTrue(prompt.contains("minute"))
    }

    @Test
    fun nextLaybyToastWhenNoneRemaining() {
        assertEquals(
            "No further laybys on this route",
            LaybyAlertFormatter.nextLaybyToast(null),
        )
    }

    @Test
    fun nextLaybyToastIncludesReplacement() {
        val toast = LaybyAlertFormatter.nextLaybyToast(
            advisory("layby-4", "Services", 12_000.0),
        )
        assertTrue(toast.contains("Next layby"))
        assertTrue(toast.contains("Services"))
    }
}
