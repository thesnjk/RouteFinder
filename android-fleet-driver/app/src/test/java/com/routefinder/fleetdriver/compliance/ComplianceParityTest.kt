package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ComplianceParityTest {
    @Test
    fun lezAvoidsNonCompliantLondonRoute() {
        val route = listOf(LatLon(51.50, -0.12), LatLon(51.51, -0.13))
        val zones = UkLezCatalog.intersectingAvoidZones(
            route = route,
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
        )
        assertTrue(zones.any { it.id == "london-ulez" })
        val message = UkLezCatalog.announcement(route, UkLezCatalog.EmissionClass.EURO4, true)
        assertNotNull(message)
        assertTrue(message!!.contains("London"))
    }

    @Test
    fun lezAvoidPolicyOmitsLondonAreaOverOrsCap() {
        val london = UkLezCatalog.zones.first { it.id == "london-ulez" }
        val ring = LezAvoidPolicy.avoidPolygonRing(london)
        assertTrue(
            LezAvoidPolicy.approximateRingAreaSquareMeters(ring) >
                LezAvoidPolicy.AVOID_POLYGON_AREA_CAP_SQUARE_METERS,
        )
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(52.0, -1.5),
            destination = LatLon(52.1, -1.4),
        )
        assertTrue(rings.none { approxEqualsCenter(it, london.center) })
    }

    @Test
    fun lezAvoidPolicyEuro4ProducesUnderCapPolygons() {
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(52.0, -1.5),
            destination = LatLon(52.1, -1.4),
        )
        assertTrue(rings.isNotEmpty())
        for (ring in rings) {
            assertTrue(
                LezAvoidPolicy.approximateRingAreaSquareMeters(ring) <=
                    LezAvoidPolicy.AVOID_POLYGON_AREA_CAP_SQUARE_METERS,
            )
            assertTrue(ring.size >= 4)
        }
    }

    @Test
    fun lezAvoidPolicyOmitsPolygonsOnLongHaul() {
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(50.7, -3.5),
            destination = LatLon(55.9, -3.2),
        )
        assertTrue(rings.isEmpty())
    }

    @Test
    fun lezAvoidPolicyOmitsPolygonsOnGlasgowToNorwich() {
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(55.8642, -4.2518),
            destination = LatLon(52.6309, 1.2974),
        )
        assertTrue(rings.isEmpty())
    }

    @Test
    fun lezAvoidPolicyWalsallToSolihullIncludesBirminghamCaz() {
        val birmingham = UkLezCatalog.zones.first { it.id == "birmingham-caz" }
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(52.586, -1.982),
            destination = LatLon(52.412, -1.778),
        )
        assertTrue(rings.isNotEmpty())
        assertTrue(rings.any { approxEqualsCenter(it, birmingham.center) })
        for (ring in rings) {
            assertTrue(
                LezAvoidPolicy.approximateRingAreaSquareMeters(ring) <=
                    LezAvoidPolicy.AVOID_POLYGON_AREA_CAP_SQUARE_METERS,
            )
        }
    }

    @Test
    fun lezAvoidPolicyOmitsZoneContainingDestination() {
        val bath = UkLezCatalog.zones.first { it.id == "bath-caz" }
        val rings = LezAvoidPolicy.polygons(
            emissionClass = UkLezCatalog.EmissionClass.EURO4,
            avoidEnabled = true,
            origin = LatLon(51.45, -2.6),
            destination = bath.center,
        )
        assertTrue(rings.none { approxEqualsCenter(it, bath.center) })
    }

    @Test
    fun orsDirectionsRequestEncodesAvoidPolygonsMultiPolygon() {
        val bath = UkLezCatalog.zones.first { it.id == "bath-caz" }
        val ring = LezAvoidPolicy.avoidPolygonRing(bath)
        val body = com.routefinder.fleetdriver.routing.OrsDirectionsRequest.buildJson(
            originLon = -2.6,
            originLat = 51.45,
            destinationLon = -2.1,
            destinationLat = 51.5,
            avoidPolygons = listOf(ring),
        )
        val avoid = body.getJSONObject("options").getJSONObject("avoid_polygons")
        assertEquals("MultiPolygon", avoid.getString("type"))
        assertTrue(avoid.getJSONArray("coordinates").length() >= 1)
    }

    private fun approxEqualsCenter(ring: List<DoubleArray>, center: LatLon): Boolean {
        if (ring.isEmpty()) return false
        val meanLon = ring.dropLast(1).map { it[0] }.average()
        val meanLat = ring.dropLast(1).map { it[1] }.average()
        return kotlin.math.abs(meanLat - center.latitude) < 0.05 &&
            kotlin.math.abs(meanLon - center.longitude) < 0.05
    }

    @Test
    fun hosClockBlocksAfterContinuousLimit() {
        val snap = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS + 60,
            dailyDriveSeconds = 2 * 3_600.0,
        )
        assertFalse(snap.canDriveNow)
        assertTrue(snap.message.contains("break", ignoreCase = true))
    }

    @Test
    fun hosClockAllowsFreshDriver() {
        val snap = HosAdvisoryClock.snapshot(0.0, 0.0)
        assertTrue(snap.canDriveNow)
        assertTrue(snap.message.contains("Can drive"))
    }

    @Test
    fun laybyFindsSiteNearM1() {
        val route = listOf(
            LatLon(52.20, -1.15),
            LatLon(52.31, -1.12),
            LatLon(52.40, -1.10),
        )
        val message = LaybyAdvisoryEngine.nearestAhead(route)
        assertNotNull(message)
        assertTrue(message!!.contains("Layby ahead"))
    }
}
