package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ParkingPartnerLinksTest {
    @Test
    fun travisUrlIncludesLatLngAndLabel() {
        val url = ParkingPartnerLinks.travisUrlString(
            latitude = 52.30600,
            longitude = -1.12200,
            label = "M1 J18 Watford Gap",
        )
        assertEquals(
            "https://www.yourtravis.com/map?lat=52.30600&lng=-1.12200&q=M1%20J18%20Watford%20Gap",
            url,
        )
    }

    @Test
    fun snapUrlIncludesLatLonAndSearch() {
        val url = ParkingPartnerLinks.snapUrlString(
            latitude = 53.00300,
            longitude = -2.28800,
            label = "M6 J15 Keele",
        )
        assertEquals(
            "https://www.snapacc.com/find-parking?lat=53.00300&lon=-2.28800&search=M6%20J15%20Keele",
            url,
        )
    }

    @Test
    fun blankLabelOmitsQueryAndSearch() {
        val travis = ParkingPartnerLinks.travisUrlString(51.5, -0.12, label = "  ")
        assertTrue(travis.startsWith("https://www.yourtravis.com/map?"))
        assertFalse(travis.contains("q="))

        val snap = ParkingPartnerLinks.snapUrlString(51.5, -0.12, label = null)
        assertTrue(snap.startsWith("https://www.snapacc.com/find-parking?"))
        assertFalse(snap.contains("search="))
    }
}
