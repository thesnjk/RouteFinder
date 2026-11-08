package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LaybyCatalogClientTest {
    private val fixture = """
        {
          "elements": [
            {
              "type": "node",
              "id": 101,
              "lat": 52.306,
              "lon": -1.122,
              "tags": { "highway": "services", "name": "Watford Gap Services" }
            },
            {
              "type": "way",
              "id": 202,
              "center": { "lat": 52.40, "lon": -1.10 },
              "tags": { "highway": "layby", "ref": "M1 Layby" }
            },
            {
              "type": "node",
              "id": 303,
              "lat": 51.0,
              "lon": 0.0,
              "tags": { "highway": "layby", "name": "Far Away" }
            }
          ]
        }
    """.trimIndent()

    @Test
    fun sitesFromOverpassJsonParsesNameAndCenter() {
        val sites = LaybyCatalogClient.sitesFromOverpassJson(fixture)
        assertEquals(3, sites.size)
        assertEquals("layby-node-101", sites[0].id)
        assertEquals("Watford Gap Services", sites[0].name)
        assertEquals("layby-way-202", sites[1].id)
        assertEquals("M1 Layby", sites[1].name)
        assertEquals(52.40, sites[1].coordinate.latitude, 1e-6)
    }

    @Test
    fun projectAndFilterKeepsCorridorHits() {
        val route = listOf(
            LatLon(52.20, -1.15),
            LatLon(52.31, -1.12),
            LatLon(52.45, -1.08),
        )
        val sites = LaybyCatalogClient.sitesFromOverpassJson(fixture)
        val projected = LaybyCatalogClient.projectAndFilter(sites, route, maxCrossTrackMeters = 2_500.0)
        assertTrue(projected.any { it.id == "layby-node-101" })
        assertTrue(projected.none { it.id == "layby-node-303" })
    }

    @Test
    fun corridorBoundingBoxesCapAndOverlap() {
        val route = (0 until 90).map { i ->
            LatLon(52.0 + i * 0.01, -1.0)
        }
        val boxes = LaybyCatalogClient.corridorBoundingBoxes(route, maxBoxes = 3)
        assertEquals(3, boxes.size)
        boxes.forEach { box ->
            val parts = box.split(",")
            assertEquals(4, parts.size)
        }
    }

    @Test
    fun engineUsesCatalogSitesWhenProvided() {
        val route = listOf(
            LatLon(52.20, -1.15),
            LatLon(52.31, -1.12),
            LatLon(52.40, -1.10),
        )
        val custom = listOf(
            LaybyAdvisoryEngine.Site(
                id = "custom-1",
                name = "Custom Rest",
                coordinate = LatLon(52.31, -1.12),
            ),
        )
        val advisory = LaybyAdvisoryEngine.nearestAhead(route = route, sites = custom)
        assertEquals("custom-1", advisory!!.site.id)
        assertTrue(advisory.message.contains("Custom Rest"))
    }
}
