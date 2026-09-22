package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ForecastClearanceRiskTest {
    @Test
    fun forecastTraffic_mapsCongestion() {
        val advisory = ForecastRiskSampler.trafficAdvisory(
            currentSpeedKmh = 10.0,
            freeFlowSpeedKmh = 80.0,
            roadClosed = false,
            arcLengthMeters = 90_000.0,
            currentArcLengthMeters = 10_000.0,
        )
        assertTrue(advisory != null)
        assertEquals(PredictiveRiskEngine.Kind.TRAFFIC, advisory!!.kind)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, advisory.severity)
        assertTrue(advisory.message.contains("bottleneck"))
    }

    @Test
    fun forecastWeather_mapsThunder() {
        val advisory = ForecastRiskSampler.weatherAdvisory(
            conditionMain = "Thunderstorm",
            windGustMps = 22.0,
            visibilityMeters = 800.0,
            arcLengthMeters = 70_000.0,
            currentArcLengthMeters = 5_000.0,
        )
        assertTrue(advisory != null)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, advisory!!.severity)
        assertTrue(advisory.message.contains("Thunderstorm"))
    }

    @Test
    fun clearance_flagsHeightConflict() {
        val hit = ClearanceCorridorProbe.ClearanceRestrictionHit(
            id = "node/1",
            latitude = 52.6,
            longitude = 1.2,
            arcLengthAlongRouteMeters = 3_000.0,
            maxHeightMeters = 3.8,
            label = "Low bridge",
        )
        val profile = HgvVehicleProfile(heightMeters = 4.2, weightTonnes = 40.0, widthMeters = 2.55)
        val advisories = ClearanceCorridorProbe.advisories(
            hits = listOf(hit),
            profile = profile,
            currentArcLengthMeters = 500.0,
        )
        assertEquals(1, advisories.size)
        assertEquals(PredictiveRiskEngine.Kind.CLEARANCE, advisories[0].kind)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, advisories[0].severity)
        assertTrue(advisories[0].message.contains("height"))
    }

    @Test
    fun parseMetersAndTonnes() {
        assertEquals(4.2, ClearanceCorridorProbe.parseMeters("4.2 m")!!, 0.001)
        assertEquals(18.0, ClearanceCorridorProbe.parseTonnes("18000 kg")!!, 0.001)
    }

    @Test
    fun fuse_includesScheduleAndSevereForecast() {
        val forecast = PredictiveRiskEngine.Advisory(
            id = "f1",
            kind = PredictiveRiskEngine.Kind.TRAFFIC,
            severity = PredictiveRiskEngine.Severity.SEVERE,
            distanceRemainingMeters = 4_000.0,
            message = "Forecast: closure risk ~1h ahead on route",
            source = "forecastTomTom",
        )
        val fused = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = "Grade",
                kineticDistanceMeters = 900.0,
                scheduleLateMessage = "Projected late to Depot by 40 min (dispatch window)",
                scheduleLateDistanceMeters = 5_000.0,
                forecastItems = listOf(forecast),
            ),
        )
        assertTrue(fused.any { it.source == "timeWindow" })
        assertTrue(fused.any { it.source == "forecastTomTom" })
        val primary = PredictiveRiskEngine.primaryAhead(fused)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, primary?.severity)
    }
}
