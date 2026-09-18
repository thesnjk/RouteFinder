package com.routefinder.fleetdriver.routing

import com.routefinder.fleetdriver.nav.TurnManeuver
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EncodedPolylineDecoderTest {
    @Test
    fun decodeEmpty() {
        assertTrue(EncodedPolylineDecoder.decode("").isEmpty())
    }

    @Test
    fun decodePrecision5Sample() {
        // Classic Google polyline sample ~ (38.5, -120.2) (40.7, -120.95) (43.252, -126.453)
        val encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
        val coords = EncodedPolylineDecoder.decode(encoded, precision = 5)
        assertEquals(3, coords.size)
        assertEquals(38.5, coords[0].latitude, 0.01)
        assertEquals(-120.2, coords[0].longitude, 0.01)
    }
}

class OrsResponseParserTest {
    @Test
    fun mapStepTypes() {
        assertEquals(TurnManeuver.DEPART, OrsResponseParser.mapStepType(1, "Head"))
        assertEquals(TurnManeuver.LEFT, OrsResponseParser.mapStepType(17, "Turn left"))
        assertEquals(TurnManeuver.ARRIVE, OrsResponseParser.mapStepType(100, "Arrive"))
        assertEquals(TurnManeuver.ROUNDABOUT, OrsResponseParser.mapStepType(25, "Roundabout"))
    }

    @Test
    fun parseMinimalGeoJson() {
        val json = JSONObject(
            """
            {
              "features": [{
                "geometry": {
                  "type": "LineString",
                  "coordinates": [[1.3, 52.63], [0.4, 52.75]]
                },
                "properties": {
                  "summary": { "distance": 70000, "duration": 3600 },
                  "segments": [{
                    "steps": [
                      { "instruction": "Head west", "distance": 100, "duration": 10, "type": 1 },
                      { "instruction": "Turn left onto High Street", "distance": 250, "duration": 30, "type": 17 },
                      { "instruction": "Arrive", "distance": 0, "duration": 0, "type": 100 }
                    ]
                  }]
                }
              }]
            }
            """.trimIndent(),
        )
        val result = OrsResponseParser.parse(json)
        assertEquals(2, result.coordinates.size)
        assertEquals(70000.0, result.distanceMeters, 0.1)
        assertTrue(result.instructions.isNotEmpty())
        assertEquals(TurnManeuver.DEPART, result.instructions.first().maneuver)
    }
}

class PeliasParseTest {
    @Test
    fun parseSuggestions() {
        val json = JSONObject(
            """
            {
              "features": [{
                "geometry": { "coordinates": [1.29, 52.63] },
                "properties": { "label": "Norwich, England" }
              }]
            }
            """.trimIndent(),
        )
        val suggestions = PeliasGeocoder.parseSuggestions(json)
        assertEquals(1, suggestions.size)
        assertEquals("Norwich, England", suggestions[0].label)
        assertEquals(52.63, suggestions[0].latitude, 0.001)
    }
}
