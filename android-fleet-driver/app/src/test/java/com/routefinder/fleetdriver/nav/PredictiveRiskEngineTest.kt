package com.routefinder.fleetdriver.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PredictiveRiskEngineTest {
    @Test
    fun fuse_prefersSevereHazardAsPrimary() {
        val advisories = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = "Steep descent",
                kineticDistanceMeters = 800.0,
                hazardMessage = "Closure ahead",
                hazardDistanceMeters = 1_200.0,
                hazardSevere = true,
            ),
        )
        assertTrue(advisories.size >= 2)
        val primary = PredictiveRiskEngine.primaryAhead(advisories)
        assertEquals(PredictiveRiskEngine.Kind.HAZARD, primary?.kind)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, primary?.severity)
    }

    @Test
    fun fuse_includesTrafficWithKinetic() {
        val advisories = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = "Grade ahead",
                kineticDistanceMeters = 900.0,
                trafficMessage = "Slow traffic ahead on corridor (~22 km/h)",
                trafficDistanceMeters = 2_500.0,
            ),
        )
        assertTrue(advisories.any { it.kind == PredictiveRiskEngine.Kind.KINETIC })
        assertTrue(advisories.any { it.kind == PredictiveRiskEngine.Kind.TRAFFIC })
        val primary = PredictiveRiskEngine.primaryAhead(advisories)
        assertTrue(primary != null)
    }

    @Test
    fun fuse_includesScheduleLateAsTraffic() {
        val advisories = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                scheduleLateMessage = "Projected late to Depot by 40 min (dispatch window)",
                scheduleLateDistanceMeters = 8_000.0,
            ),
        )
        assertTrue(advisories.any { it.source == "timeWindow" })
        assertEquals(PredictiveRiskEngine.Kind.TRAFFIC, advisories.first().kind)
    }

    @Test
    fun fuse_prefersSevereForecast() {
        val severe = PredictiveRiskEngine.Advisory(
            id = "forecast-1",
            kind = PredictiveRiskEngine.Kind.TRAFFIC,
            severity = PredictiveRiskEngine.Severity.SEVERE,
            distanceRemainingMeters = 5_000.0,
            message = "Forecast: closure risk ~1h ahead on route",
            source = "forecastTomTom",
        )
        val advisories = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = "Grade",
                kineticDistanceMeters = 800.0,
                forecastItems = listOf(severe),
            ),
        )
        val primary = PredictiveRiskEngine.primaryAhead(advisories)
        assertEquals(PredictiveRiskEngine.Severity.SEVERE, primary?.severity)
        assertEquals("forecastTomTom", primary?.source)
    }

    @Test
    fun fuse_includesClearanceAndRoadworks() {
        val clearance = PredictiveRiskEngine.Advisory(
            id = "clearance-1",
            kind = PredictiveRiskEngine.Kind.CLEARANCE,
            severity = PredictiveRiskEngine.Severity.SEVERE,
            distanceRemainingMeters = 1_500.0,
            message = "Clearance: bridge — height 4.2m > limit 3.8m",
            source = "clearanceOverpass",
        )
        val advisories = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                roadworksMessage = "Roadworks ahead",
                roadworksDistanceMeters = 2_000.0,
                clearanceItems = listOf(clearance),
            ),
        )
        assertTrue(advisories.any { it.kind == PredictiveRiskEngine.Kind.ROADWORKS })
        assertTrue(advisories.any { it.kind == PredictiveRiskEngine.Kind.CLEARANCE })
    }
}
