package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingParkingBookReturnTest {
    @Test
    fun ctaCaptionByTier() {
        assertNull(ParkingBookCtaCopy.caption(null))
        assertNull(ParkingBookCtaCopy.caption(ParkingAvailabilityTier.AMPLE))
        assertTrue(ParkingBookCtaCopy.caption(ParkingAvailabilityTier.LIMITED)!!.contains("fill soon"))
        assertTrue(ParkingBookCtaCopy.caption(ParkingAvailabilityTier.FULL)!!.contains("full"))
    }

    @Test
    fun travisEmphasisOnlyForAmple() {
        assertTrue(ParkingBookCtaCopy.emphasizesTravis(ParkingAvailabilityTier.AMPLE))
        assertFalse(ParkingBookCtaCopy.emphasizesTravis(ParkingAvailabilityTier.LIMITED))
        assertFalse(ParkingBookCtaCopy.emphasizesTravis(ParkingAvailabilityTier.FULL))
        assertTrue(ParkingBookCtaCopy.usesSecondaryBookStyle(ParkingAvailabilityTier.FULL))
        assertFalse(ParkingBookCtaCopy.usesSecondaryBookStyle(ParkingAvailabilityTier.AMPLE))
    }

    @Test
    fun pendingFreshnessWindow() {
        val now = 1_700_000_000_000L
        val fresh = PendingParkingBookReturn(
            id = "a",
            label = "Keele",
            latitude = 53.0,
            longitude = -2.2,
            partner = ParkingBookPartner.TRAVIS,
            openedAtMs = now - 60_000L,
            tier = ParkingAvailabilityTier.AMPLE,
        )
        assertTrue(fresh.isFresh(now))
        assertTrue(fresh.resumeMessage.contains("TRAVIS"))
        assertTrue(fresh.resumeMessage.contains("Keele"))

        val stale = PendingParkingBookReturn(
            id = "b",
            label = "Old",
            latitude = 53.0,
            longitude = -2.2,
            partner = ParkingBookPartner.SNAP,
            openedAtMs = now - PendingParkingBookReturn.FRESHNESS_LIMIT_MS - 1L,
            tier = ParkingAvailabilityTier.FULL,
        )
        assertFalse(stale.isFresh(now))
        assertEquals("SNAP", ParkingBookPartner.SNAP.displayName)
    }
}
