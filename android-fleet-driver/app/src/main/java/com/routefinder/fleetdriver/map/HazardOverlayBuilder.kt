package com.routefinder.fleetdriver.map

import com.routefinder.fleetdriver.hazard.HazardEvent
import org.json.JSONArray
import org.json.JSONObject

/** Builds map hazard overlay GeoJSON from structured hazard events (iOS Ph40 parity). */
object HazardOverlayBuilder {
    const val PIN_COLOR = "#ef4444"

    /** Empty FeatureCollection used when no hazards are active. */
    const val EMPTY_FEATURE_COLLECTION =
        "{\"type\":\"FeatureCollection\",\"features\":[]}"

    /** Serializes hazards as a GeoJSON FeatureCollection for MapLibre overlays. */
    fun geoJSON(from: List<HazardEvent>): String {
        if (from.isEmpty()) return EMPTY_FEATURE_COLLECTION
        val features = JSONArray()
        for (hazard in from) {
            features.put(featureJSON(hazard))
        }
        return JSONObject()
            .put("type", "FeatureCollection")
            .put("features", features)
            .toString()
    }

    private fun featureJSON(hazard: HazardEvent): JSONObject {
        val properties = JSONObject()
            .put("id", hazard.id)
            .put("color", PIN_COLOR)
            .put("title", hazard.type.name.lowercase())
            .put("source", hazard.source)
        val geometry = JSONObject()
            .put("type", "Point")
            .put(
                "coordinates",
                JSONArray().put(hazard.longitude).put(hazard.latitude),
            )
        return JSONObject()
            .put("type", "Feature")
            .put("properties", properties)
            .put("geometry", geometry)
    }
}
