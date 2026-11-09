package com.routefinder.fleetdriver.map

import com.routefinder.fleetdriver.hazard.HazardEvent
import com.routefinder.fleetdriver.hazard.HazardEventType
import com.routefinder.fleetdriver.hazard.HazardSeverity
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HazardOverlayBuilderTest {
    @Test
    fun emptyCollection() {
        assertEquals(
            HazardOverlayBuilder.EMPTY_FEATURE_COLLECTION,
            HazardOverlayBuilder.geoJSON(emptyList()),
        )
    }

    @Test
    fun producesFeatureCollectionForTwoHazards() {
        val now = System.currentTimeMillis()
        val hazards = listOf(
            HazardEvent(
                id = "h1",
                latitude = 52.1,
                longitude = -0.5,
                radiusMeters = 90.0,
                type = HazardEventType.CLOSURE,
                severity = HazardSeverity.MODERATE,
                validFromEpochMs = now,
                validToEpochMs = now + 3_600_000,
                source = "crowd:test",
            ),
            HazardEvent(
                id = "h2",
                latitude = 52.2,
                longitude = -0.6,
                radiusMeters = 90.0,
                type = HazardEventType.TRAFFIC,
                severity = HazardSeverity.MODERATE,
                validFromEpochMs = now,
                validToEpochMs = now + 3_600_000,
                source = "crowd:test",
            ),
        )
        val json = HazardOverlayBuilder.geoJSON(hazards)
        val root = JSONObject(json)
        assertEquals("FeatureCollection", root.getString("type"))
        val features = root.getJSONArray("features")
        assertEquals(2, features.length())
        val first = features.getJSONObject(0)
        assertEquals("Feature", first.getString("type"))
        assertEquals("#ef4444", first.getJSONObject("properties").getString("color"))
        val coords = first.getJSONObject("geometry").getJSONArray("coordinates")
        assertEquals(-0.5, coords.getDouble(0), 1e-9)
        assertEquals(52.1, coords.getDouble(1), 1e-9)
        assertTrue(json.contains("h2"))
    }
}
