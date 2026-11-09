package com.routefinder.fleetdriver.map

import com.routefinder.fleetdriver.compliance.LaybyAdvisoryEngine
import com.routefinder.fleetdriver.compliance.ParkingAvailabilityTier
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point

/**
 * Ahead parking / layby marker for the MapLibre canvas (CoPilot-style availability colors).
 */
data class ParkingMapMarker(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val tier: ParkingAvailabilityTier,
    val title: String,
)

/**
 * Builds parking map markers from ranked layby advisories.
 * Crowd/prior tiers only — not live bay counts.
 */
object ParkingMapMarkerBuilder {
    const val DEFAULT_MAX_MARKERS = 8

    const val COLOR_AMPLE = "#22c55e"
    const val COLOR_LIMITED = "#f59e0b"
    const val COLOR_FULL = "#ef4444"

    fun colorHex(tier: ParkingAvailabilityTier): String =
        when (tier) {
            ParkingAvailabilityTier.AMPLE -> COLOR_AMPLE
            ParkingAvailabilityTier.LIMITED -> COLOR_LIMITED
            ParkingAvailabilityTier.FULL -> COLOR_FULL
        }

    fun markers(
        advisories: List<LaybyAdvisoryEngine.Advisory>,
        maxMarkers: Int = DEFAULT_MAX_MARKERS,
    ): List<ParkingMapMarker> {
        if (maxMarkers <= 0) return emptyList()
        return advisories.take(maxMarkers).map { advisory ->
            ParkingMapMarker(
                id = "parking-${advisory.site.id}",
                latitude = advisory.site.coordinate.latitude,
                longitude = advisory.site.coordinate.longitude,
                tier = advisory.tier,
                title = "${advisory.site.name} · ${advisory.tier.displayLabel}",
            )
        }
    }

    fun toFeatureCollection(markers: List<ParkingMapMarker>): FeatureCollection {
        val features = markers.map { marker ->
            Feature.fromGeometry(
                Point.fromLngLat(marker.longitude, marker.latitude),
            ).also { feature ->
                feature.addStringProperty("id", marker.id)
                feature.addStringProperty("tier", marker.tier.name)
                feature.addStringProperty("title", marker.title)
                feature.addStringProperty("color", colorHex(marker.tier))
            }
        }
        return FeatureCollection.fromFeatures(features)
    }
}
