package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ParkingAvailabilityTierTest {
    @Test
    fun occupancyPriorInvertsToAvailability() {
        assertEquals(
            ParkingAvailabilityTier.AMPLE,
            ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.LOW),
        )
        assertEquals(
            ParkingAvailabilityTier.LIMITED,
            ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.MODERATE),
        )
        assertEquals(
            ParkingAvailabilityTier.FULL,
            ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.HIGH),
        )
    }

    @Test
    fun confidenceFloorsMatchIos() {
        assertEquals(ParkingAvailabilityTier.AMPLE, ParkingAvailabilityTier.fromConfidence(0.9))
        assertEquals(ParkingAvailabilityTier.AMPLE, ParkingAvailabilityTier.fromConfidence(0.72))
        assertEquals(ParkingAvailabilityTier.LIMITED, ParkingAvailabilityTier.fromConfidence(0.55))
        assertEquals(ParkingAvailabilityTier.LIMITED, ParkingAvailabilityTier.fromConfidence(0.48))
        assertEquals(ParkingAvailabilityTier.FULL, ParkingAvailabilityTier.fromConfidence(0.3))
    }

    @Test
    fun eveningPriorHigherOccupancyThanMidday() {
        val midday = LaybyOccupancyPrior.forHour(12)
        val evening = LaybyOccupancyPrior.forHour(19)
        assertEquals(LaybyOccupancyPrior.MODERATE, midday)
        assertEquals(LaybyOccupancyPrior.HIGH, evening)
        assertTrue(
            LaybyOccupancyPrior.availabilityMultiplier(19) <
                LaybyOccupancyPrior.availabilityMultiplier(12),
        )
    }

    @Test
    fun storeTapOverridesHourPrior() {
        val store = LaybyOccupancyStore.inMemory()
        val siteId = "m1-watford-gap"

        assertEquals(
            ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.forHour(12)),
            store.resolveTier(siteId, hour = 12),
        )

        store.record(siteId, LaybyOccupancyKind.FULL, Instant.now())
        assertEquals(ParkingAvailabilityTier.FULL, store.resolveTier(siteId, hour = 12))

        store.record(siteId, LaybyOccupancyKind.SPACES_AVAILABLE, Instant.now())
        assertEquals(ParkingAvailabilityTier.AMPLE, store.resolveTier(siteId, hour = 19))
    }

    @Test
    fun staleTapIgnored() {
        val store = LaybyOccupancyStore.inMemory()
        val siteId = "m6-keele"
        val stale = Instant.now().minusSeconds((7 * 3600).toLong())
        store.record(siteId, LaybyOccupancyKind.FULL, stale)
        assertNull(store.latest(siteId))
        assertEquals(
            ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.forHour(10)),
            store.resolveTier(siteId, hour = 10),
        )
    }
}
