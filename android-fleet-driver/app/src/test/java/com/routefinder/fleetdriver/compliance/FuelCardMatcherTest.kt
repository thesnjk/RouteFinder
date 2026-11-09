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

    @Test
    fun parsesWeighbridgeAndOvernightParking() {
        val json = """
            {
              "elements": [
                {
                  "type": "node",
                  "id": 10,
                  "lat": 52.2,
                  "lon": 0.3,
                  "tags": { "man_made": "weighbridge", "name": "DVSA weigh" }
                },
                {
                  "type": "node",
                  "id": 11,
                  "lat": 52.25,
                  "lon": 0.35,
                  "tags": { "highway": "weigh_station" }
                },
                {
                  "type": "node",
                  "id": 12,
                  "lat": 52.3,
                  "lon": 0.4,
                  "tags": {
                    "amenity": "parking",
                    "hgv": "yes",
                    "name": "Secure truck park",
                    "supervised": "yes"
                  }
                },
                {
                  "type": "node",
                  "id": 13,
                  "lat": 52.35,
                  "lon": 0.45,
                  "tags": {
                    "amenity": "fuel",
                    "hgv": "yes",
                    "name": "Keyfuels stop",
                    "brand": "Keyfuels"
                  }
                }
              ]
            }
        """.trimIndent()
        val pois = FuelPoiCatalogClient.poisFromOverpassJson(json)
        assertEquals(4, pois.size)
        assertEquals(TruckFuelPoi.Kind.WEIGH_STATION, pois[0].kind)
        assertEquals("DVSA weigh", pois[0].label)
        assertEquals(TruckFuelPoi.Kind.WEIGH_STATION, pois[1].kind)
        assertEquals("Weighbridge", pois[1].label)
        assertEquals(TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING, pois[2].kind)
        assertEquals(TruckFuelPoi.Kind.HIGH_FLOW_DIESEL, pois[3].kind)
        assertTrue(FuelCardMatcher.accepts(FuelCardProvider.KEYFUELS, pois[3]))
        assertFalse(FuelCardMatcher.accepts(FuelCardProvider.KEYFUELS, pois[0]))
    }

    @Test
    fun weighBannerReflectsCount() {
        assertNull(WeighStationAhead.bannerMessage(0))
        assertEquals("Weighbridge ahead on route", WeighStationAhead.bannerMessage(1))
        assertEquals("3 weighbridges ahead on route", WeighStationAhead.bannerMessage(3))
    }
}
