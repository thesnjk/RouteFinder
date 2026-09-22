package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ForecastAndClearanceRiskTest {
    @Test
    fun forecastTrafficAdvisory_mapsCongestion() {
        val advisory = ForecastRiskSampler.trafficAdvisory(
            currentSpeedKmh = 10.0,
            freeFlowSpeedKmh = 60.0,
            roadClosed = false,
            arcLengthMeters = 60_000.0,
            currentArcLengthMeters = 0.0,
        )
        assertNotNull(advisory)
        assertEquals(PredictiveRiskEngine.Kind.TRAFFIC, advisory!!.kind)
        assertTrue(advisory.message.contains("bottleneck"))
    }

    @Test
    fun forecastWeatherAdvisory_mapsSevereThunder() {
        val advisory = ForecastRiskSampler.weatherAdvisory(
            conditionMain = "Thunderstorm",
            windGustMps = 20.0,
            visibilityMeters = 800.0,
            arcLengthMeters = 120_000.0,
            currentArcLengthMeters = 0.0,
        )
        assertNotNull(advisory)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, advisory!!.severity)
        assertEquals(PredictiveRiskEngine.Kind.WEATHER, advisory.kind)
    }

    @Test
    fun clearanceProbe_flagsHeightConflict() {
        val hit = ClearanceCorridorProbe.ClearanceRestrictionHit(
            id = "node/1",
            latitude = 52.6,
            longitude = 1.2,
            arcLengthAlongRouteMeters = 3_000.0,
            maxHeightMeters = 3.8,
            label = "Low bridge",
        )
        val advisories = ClearanceCorridorProbe.advisories(
            hits = listOf(hit),
            profile = HgvVehicleProfile(heightMeters = 4.2),
            currentArcLengthMeters = 0.0,
        )
        assertEquals(1, advisories.size)
        assertEquals(PredictiveRiskEngine.Kind.CLEARANCE, advisories.first().kind)
        assertTrue(advisories.first().message.contains("height"))
    }

    @Test
    fun clearanceParseMetersAndTonnes() {
        assertEquals(4.2, ClearanceCorridorProbe.parseMeters("4.2 m")!!, 0.001)
        assertEquals(18.0, ClearanceCorridorProbe.parseTonnes("18000 kg")!!, 0.001)
    }

    @Test
    fun forecastShouldRefresh_respectsInterval() {
        assertTrue(ForecastRiskSampler.shouldRefresh(null))
        assertTrue(ForecastRiskSampler.shouldRefresh(0L, nowMs = ForecastRiskSampler.REFRESH_INTERVAL_MS + 1))
        assertTrue(!ForecastRiskSampler.shouldRefresh(1_000L, nowMs = 2_000L))
    }

    @Test
    fun clearanceHeadingCorridor_buildsEastPolyline() {
        val origin = LatLon(52.6, 1.3)
        val corridor = ClearanceCorridorProbe.headingCorridor(
            from = origin,
            bearingDegrees = 90.0,
            lengthMeters = 1_000.0,
            stepMeters = 250.0,
        )
        assertTrue(corridor.size >= 4)
        assertEquals(origin.latitude, corridor.first().latitude, 0.0001)
        assertTrue(corridor.last().longitude > origin.longitude)
    }

    @Test
    fun clearanceIsOffRoute_whenFarFromSpine() {
        val route = listOf(LatLon(52.60, 1.30), LatLon(52.61, 1.30))
        val onRoute = ClearanceCorridorProbe.isOffRoute(LatLon(52.605, 1.3001), route)
        assertTrue(!onRoute.first)
        val off = ClearanceCorridorProbe.isOffRoute(LatLon(52.605, 1.32), route)
        assertTrue(off.first)
        assertTrue(off.second > ClearanceCorridorProbe.OFF_ROUTE_CROSS_TRACK_THRESHOLD_METERS)
    }
}
