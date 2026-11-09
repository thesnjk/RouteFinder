package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FuelCardMatcherTest {
    @Test
    fun matchesKeyfuelsByLabelSubstring() {
        val poi = TruckFuelPoi(
            id = "fuel-1",
            label = "Keyfuels Truck Stop",
            latitude = 51.5,
            longitude = -0.1,
            amenities = setOf("fuel", "brand:keyfuels"),
        )
        assertTrue(FuelCardMatcher.accepts(FuelCardProvider.KEYFUELS, poi))
        assertFalse(FuelCardMatcher.accepts(FuelCardProvider.BP, poi))
    }

    @Test
    fun matchesBrandAmenityWhenLabelIsGeneric() {
        val poi = TruckFuelPoi(
            id = "fuel-2",
            label = "HGV fuel",
            latitude = 51.5,
            longitude = -0.1,
            amenities = setOf("fuel", "brand:esso"),
        )
        assertTrue(FuelCardMatcher.accepts(FuelCardProvider.ESSO, poi))
    }

    @Test
    fun ignoresNonFuelPois() {
        val poi = TruckFuelPoi(
            id = "park-1",
            label = "BP Truck Park",
            latitude = 51.5,
            longitude = -0.1,
            amenities = setOf("brand:bp"),
            kind = TruckFuelPoi.Kind.OTHER,
        )
        assertFalse(FuelCardMatcher.accepts(FuelCardProvider.BP, poi))
    }

    @Test
    fun bannerMessageReflectsMatchCount() {
        assertNull(FuelCardMatcher.aheadBannerMessage(FuelCardProvider.NONE, 2))
        assertNull(FuelCardMatcher.aheadBannerMessage(FuelCardProvider.BP, 0))
        assertEquals(
            "Accepts your BP card ahead",
            FuelCardMatcher.aheadBannerMessage(FuelCardProvider.BP, 1),
        )
        assertEquals(
            "3 stops ahead accept your UK Fuels card",
            FuelCardMatcher.aheadBannerMessage(FuelCardProvider.UK_FUELS, 3),
        )
    }
}

class FuelPoiCatalogClientTest {
    @Test
    fun parsesHgvFuelWithBrand() {
        val json = """
            {
              "elements": [{
                "type": "node",
                "id": 42,
                "lat": 52.1,
                "lon": 0.2,
                "tags": {
                  "amenity": "fuel",
                  "hgv": "yes",
                  "name": "BP Connect",
                  "brand": "BP"
                }
              }]
            }
        """.trimIndent()
        val pois = FuelPoiCatalogClient.poisFromOverpassJson(json)
        assertEquals(1, pois.size)
        assertEquals(TruckFuelPoi.Kind.HIGH_FLOW_DIESEL, pois[0].kind)
        assertTrue(pois[0].amenities.any { it.startsWith("brand:bp") })
        assertTrue(FuelCardMatcher.accepts(FuelCardProvider.BP, pois[0]))
    }

    @Test
    fun skipsNonHgvFuel() {
        val json = """
            {
              "elements": [{
                "type": "node",
                "id": 7,
                "lat": 52.1,
                "lon": 0.2,
                "tags": { "amenity": "fuel", "name": "Corner garage" }
              }]
            }
        """.trimIndent()
        assertTrue(FuelPoiCatalogClient.poisFromOverpassJson(json).isEmpty())
    }
}
