package com.routefinder.fleetdriver.map

import com.routefinder.fleetdriver.compliance.LaybyAdvisoryEngine
import com.routefinder.fleetdriver.compliance.LaybyOccupancyPrior
import com.routefinder.fleetdriver.compliance.ParkingAvailabilityTier
import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ParkingMapMarkerBuilderTest {
    @Test
    fun colorHexMatchesCoPilotStyleBands() {
        assertEquals(ParkingMapMarkerBuilder.COLOR_AMPLE, ParkingMapMarkerBuilder.colorHex(ParkingAvailabilityTier.AMPLE))
        assertEquals(ParkingMapMarkerBuilder.COLOR_LIMITED, ParkingMapMarkerBuilder.colorHex(ParkingAvailabilityTier.LIMITED))
        assertEquals(ParkingMapMarkerBuilder.COLOR_FULL, ParkingMapMarkerBuilder.colorHex(ParkingAvailabilityTier.FULL))
    }

    @Test
    fun markersFromAdvisoriesCapAndMapTier() {
        val advisories = (0 until 12).map { index ->
            LaybyAdvisoryEngine.Advisory(
                site = LaybyAdvisoryEngine.Site(
                    id = "site-$index",
                    name = "Site $index",
                    coordinate = LatLon(52.0 + index * 0.01, -1.0),
                ),
                remainingMeters = (index + 1) * 1_000.0,
                message = "ahead",
                tier = if (index % 3 == 0) {
                    ParkingAvailabilityTier.AMPLE
                } else if (index % 3 == 1) {
                    ParkingAvailabilityTier.LIMITED
                } else {
                    ParkingAvailabilityTier.FULL
                },
                occupancyPrior = LaybyOccupancyPrior.LOW,
            )
        }
        val markers = ParkingMapMarkerBuilder.markers(advisories, maxMarkers = 8)
        assertEquals(8, markers.size)
        assertEquals("parking-site-0", markers[0].id)
        assertEquals(ParkingAvailabilityTier.AMPLE, markers[0].tier)
        assertTrue(markers[0].title.contains("Spaces"))
    }

    @Test
    fun emptyAdvisoriesYieldEmptyCollection() {
        assertTrue(ParkingMapMarkerBuilder.markers(emptyList()).isEmpty())
        val collection = ParkingMapMarkerBuilder.toFeatureCollection(emptyList())
        assertEquals(0, collection.features()?.size ?: 0)
    }

    @Test
    fun featureCollectionIncludesTierProperty() {
        val markers = listOf(
            ParkingMapMarker(
                id = "parking-a",
                latitude = 51.5,
                longitude = -0.1,
                tier = ParkingAvailabilityTier.FULL,
                title = "Full yard",
            ),
        )
        val feature = ParkingMapMarkerBuilder.toFeatureCollection(markers).features()!!.first()
        assertEquals("FULL", feature.getStringProperty("tier"))
        assertEquals(ParkingMapMarkerBuilder.COLOR_FULL, feature.getStringProperty("color"))
    }
}
