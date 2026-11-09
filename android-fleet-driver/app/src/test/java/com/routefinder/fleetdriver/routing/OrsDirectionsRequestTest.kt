package com.routefinder.fleetdriver.routing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OrsDirectionsRequestTest {
    @Test
    fun avoidTollsAddsTollwaysFeature() {
        val json = OrsDirectionsRequest.buildJson(
            originLon = -0.1,
            originLat = 51.5,
            destinationLon = -0.2,
            destinationLat = 51.6,
            avoidTolls = true,
        )
        val options = json.getJSONObject("options")
        assertTrue(options.has("avoid_features"))
        val features = options.getJSONArray("avoid_features")
        val values = (0 until features.length()).map { features.getString(it) }
        assertTrue(values.contains("tollways"))
    }

    @Test
    fun avoidTollsOffOmitsTollways() {
        val json = OrsDirectionsRequest.buildJson(
            originLon = -0.1,
            originLat = 51.5,
            destinationLon = -0.2,
            destinationLat = 51.6,
            avoidTolls = false,
        )
        val options = json.getJSONObject("options")
        if (!options.has("avoid_features")) return
        val features = options.getJSONArray("avoid_features")
        val values = (0 until features.length()).map { features.getString(it) }
        assertFalse(values.contains("tollways"))
    }
}
