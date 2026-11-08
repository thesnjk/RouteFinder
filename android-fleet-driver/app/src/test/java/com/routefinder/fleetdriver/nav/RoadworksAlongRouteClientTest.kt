package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RoadworksAlongRouteClientTest {
    private val fixture = """
        {
          "elements": [
            {
              "type": "node",
              "id": 11,
              "lat": 52.31,
              "lon": -1.12,
              "tags": { "highway": "construction", "name": "M1 resurfacing" }
            },
            {
              "type": "way",
              "id": 22,
              "center": { "lat": 52.40, "lon": -1.10 },
              "tags": { "highway": "construction", "description": "Lane closure" }
            },
            {
              "type": "node",
              "id": 33,
              "lat": 51.0,
              "lon": 0.0,
              "tags": { "construction": "yes", "name": "Far Away Works" }
            }
          ]
        }
    """.trimIndent()

    @Before
    fun clearCache() {
        RoadworksAlongRouteClient.clearCache()
    }

    @Test
    fun sitesFromOverpassJsonParsesNameAndDescription() {
        val sites = RoadworksAlongRouteClient.sitesFromOverpassJson(fixture)
        assertEquals(3, sites.size)
        assertEquals("node/11", sites[0].id)
        assertEquals("M1 resurfacing", sites[0].label)
        assertEquals("way/22", sites[1].id)
        assertEquals("Lane closure", sites[1].label)
    }

    @Test
    fun projectAndFilterKeepsCorridorHits() {
        val route = listOf(
            LatLon(52.20, -1.15),
            LatLon(52.31, -1.12),
            LatLon(52.45, -1.08),
        )
        val raw = RoadworksAlongRouteClient.sitesFromOverpassJson(fixture)
        val projected = RoadworksAlongRouteClient.projectAndFilter(
            sites = raw,
            route = route,
            maxCrossTrackMeters = 2_500.0,
        )
        assertTrue(projected.any { it.id == "node/11" })
        assertTrue(projected.none { it.id == "node/33" })
        assertNotNull(projected.first { it.id == "node/11" }.arcLengthAlongRouteMeters)
    }

    @Test
    fun nearestAheadAndBannerUseMetric() {
        val site = RoadworkSite(
            id = "node/11",
            label = "M1 resurfacing",
            latitude = 52.31,
            longitude = -1.12,
            arcLengthAlongRouteMeters = 8_000.0,
        )
        val ahead = RoadworksAheadFormatter.nearestAhead(
            sites = listOf(site),
            currentArcLengthMeters = 2_000.0,
        )
        assertEquals("node/11", ahead!!.id)
        val banner = RoadworksAheadFormatter.bannerMessage(site, currentArcLengthMeters = 2_000.0)
        assertNotNull(banner)
        assertTrue(banner!!.contains("km"))
        assertTrue(banner.contains("Roadworks"))
        assertEquals(6_000.0, RoadworksAheadFormatter.remainingMeters(site, 2_000.0)!!, 0.1)
    }

    @Test
    fun nearestAheadSkipsBehindAndFar() {
        val behind = RoadworkSite("a", "Behind", 52.0, -1.0, arcLengthAlongRouteMeters = 500.0)
        val far = RoadworkSite("b", "Far", 52.0, -1.0, arcLengthAlongRouteMeters = 50_000.0)
        assertNull(
            RoadworksAheadFormatter.nearestAhead(
                sites = listOf(behind, far),
                currentArcLengthMeters = 1_000.0,
                maxAheadMeters = 32_000.0,
            ),
        )
    }
}
