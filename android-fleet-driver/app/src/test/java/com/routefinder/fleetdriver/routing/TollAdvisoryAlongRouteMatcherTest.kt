package com.routefinder.fleetdriver.routing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TollAdvisoryAlongRouteMatcherTest {
    @Test
    fun catalogHasMajorCrossingsWithIndicativeGBP() {
        assertTrue(UKTollAdvisoryCatalog.all.size >= 14)
        val dartford = UKTollAdvisoryCatalog.advisory("dartford-crossing")
        val m6 = UKTollAdvisoryCatalog.advisory("m6-toll")
        val tyne = UKTollAdvisoryCatalog.advisory("tyne-tunnel")
        val queensway = UKTollAdvisoryCatalog.advisory("mersey-tunnels-queensway")
        val kingsway = UKTollAdvisoryCatalog.advisory("mersey-tunnels-kingsway")
        val dunham = UKTollAdvisoryCatalog.advisory("dunham-bridge")
        val batheaston = UKTollAdvisoryCatalog.advisory("batheaston-bridge")
        val severn = UKTollAdvisoryCatalog.advisory("severn-crossings")
        assertNotNull(dunham)
        assertNotNull(batheaston)
        assertEquals(8.40, dartford?.indicativeCostGBP!!, 0.001)
        assertEquals(20.20, m6?.indicativeCostGBP!!, 0.001)
        assertEquals(5.20, tyne?.indicativeCostGBP!!, 0.001)
        assertEquals(4.80, queensway?.indicativeCostGBP!!, 0.001)
        assertEquals(4.80, kingsway?.indicativeCostGBP!!, 0.001)
        assertEquals(4.00, dunham?.indicativeCostGBP!!, 0.001)
        assertNull(batheaston?.indicativeCostGBP)
        assertNull(severn?.indicativeCostGBP)
    }

    @Test
    fun matcherHitsDartfordPolyline() {
        val dartford = UKTollAdvisoryCatalog.advisory("dartford-crossing")!!
        val polyline = listOf(
            LatLon(dartford.latitude - 0.01, dartford.longitude - 0.01),
            LatLon(dartford.latitude, dartford.longitude),
            LatLon(dartford.latitude + 0.01, dartford.longitude + 0.01),
        )
        val hits = TollAdvisoryAlongRouteMatcher.advisories(along = polyline)
        assertTrue(hits.any { it.id == "dartford-crossing" })
    }

    @Test
    fun matcherIgnoresDistantRoute() {
        val scotland = listOf(
            LatLon(57.15, -2.10),
            LatLon(57.20, -2.05),
        )
        val hits = TollAdvisoryAlongRouteMatcher.advisories(
            along = scotland,
            catalog = listOf(UKTollAdvisoryCatalog.advisory("dartford-crossing")!!),
        )
        assertTrue(hits.isEmpty())
    }

    @Test
    fun indicativeRouteTotalSumsMatchedCosts() {
        val dartford = UKTollAdvisoryCatalog.advisory("dartford-crossing")!!
        val m6 = UKTollAdvisoryCatalog.advisory("m6-toll")!!
        val severn = UKTollAdvisoryCatalog.advisory("severn-crossings")!!
        val total = UKTollAdvisory.indicativeRouteTotalGBP(listOf(dartford, m6, severn))
        assertEquals(dartford.indicativeCostGBP!! + m6.indicativeCostGBP!!, total!!, 0.001)
        assertNotNull(UKTollAdvisory.indicativeRouteTotalLabel(listOf(dartford, m6)))
        assertNull(UKTollAdvisory.indicativeRouteTotalGBP(listOf(severn)))
    }

    @Test
    fun nextAdvisoryWithinHorizon() {
        val dartford = UKTollAdvisoryCatalog.advisory("dartford-crossing")!!
        val polyline = listOf(
            LatLon(dartford.latitude - 0.005, dartford.longitude),
            LatLon(dartford.latitude, dartford.longitude),
        )
        val near = LatLon(dartford.latitude - 0.002, dartford.longitude)
        val next = TollAdvisoryAlongRouteMatcher.nextAdvisory(
            along = polyline,
            near = near,
            catalog = listOf(dartford),
        )
        assertNotNull(next)
        assertEquals("dartford-crossing", next!!.first.id)
        assertTrue(next.second <= 5_000.0)
    }

    @Test
    fun severnHasNoIndicativeCostLabel() {
        val severn = UKTollAdvisoryCatalog.advisory("severn-crossings")!!
        assertNull(severn.indicativeCostLabel)
        assertFalse(
            UKTollAdvisory.indicativeRouteTotalLabel(listOf(severn)) != null,
        )
    }
}
