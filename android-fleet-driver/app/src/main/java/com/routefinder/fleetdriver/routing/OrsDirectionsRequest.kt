package com.routefinder.fleetdriver.routing

import org.json.JSONArray
import org.json.JSONObject

/** Default UK articulated HGV dimensions (metres / tonnes) used for ORS restrictions. */
data class HgvVehicleProfile(
    val lengthMeters: Double = 16.5,
    val widthMeters: Double = 2.55,
    val heightMeters: Double = 4.0,
    val weightTonnes: Double = 40.0,
    val axleLoadTonnes: Double = 11.5,
    /** When true, ORS `hazmat` restriction is enabled (ADR load). */
    val hazmat: Boolean = false,
    /** Optional ORS tunnel restriction code (e.g. `B`, `C`). */
    val hazmatTunnelRestrictionCode: String? = null,
)

/** Builds ORS driving-hgv GeoJSON directions request body. */
object OrsDirectionsRequest {
    fun buildJson(
        originLon: Double,
        originLat: Double,
        destinationLon: Double,
        destinationLat: Double,
        via: List<Pair<Double, Double>> = emptyList(),
        vehicle: HgvVehicleProfile = HgvVehicleProfile(),
        avoidTolls: Boolean = false,
        avoidFerries: Boolean = false,
        avoidTunnels: Boolean = false,
        /** Closed `[lon, lat]` rings for ORS GeoJSON MultiPolygon `avoid_polygons`. */
        avoidPolygons: List<List<DoubleArray>> = emptyList(),
    ): JSONObject {
        val coordinates = JSONArray().apply {
            put(JSONArray().put(originLon).put(originLat))
            via.forEach { (lon, lat) -> put(JSONArray().put(lon).put(lat)) }
            put(JSONArray().put(destinationLon).put(destinationLat))
        }

        val avoidFeatures = JSONArray()
        if (avoidTolls) avoidFeatures.put("tollways")
        if (avoidFerries) avoidFeatures.put("ferries")
        if (avoidTunnels) avoidFeatures.put("tunnels")

        val restrictions = JSONObject()
            .put("length", vehicle.lengthMeters)
            .put("width", vehicle.widthMeters)
            .put("height", vehicle.heightMeters)
            .put("weight", vehicle.weightTonnes)
            .put("axleload", vehicle.axleLoadTonnes)
        if (vehicle.hazmat) {
            restrictions.put("hazmat", true)
            vehicle.hazmatTunnelRestrictionCode?.let {
                restrictions.put("hazmat_tunnel_restriction_code", it)
            }
        }

        val options = JSONObject()
            .put(
                "profile_params",
                JSONObject().put("restrictions", restrictions),
            )
        if (avoidFeatures.length() > 0) {
            options.put("avoid_features", avoidFeatures)
        }
        if (avoidPolygons.isNotEmpty()) {
            options.put("avoid_polygons", avoidPolygonsGeoJson(avoidPolygons))
        }

        return JSONObject()
            .put("coordinates", coordinates)
            .put("options", options)
            .put("instructions", true)
            .put("geometry", true)
            .put("elevation", true)
    }

    /** GeoJSON MultiPolygon: each ring becomes one Polygon with a single exterior ring. */
    fun avoidPolygonsGeoJson(rings: List<List<DoubleArray>>): JSONObject {
        val coordinates = JSONArray()
        for (ring in rings) {
            val closed = ensureClosed(ring)
            val ringArr = JSONArray()
            for (pos in closed) {
                ringArr.put(JSONArray().put(pos[0]).put(pos[1]))
            }
            coordinates.put(JSONArray().put(ringArr))
        }
        return JSONObject()
            .put("type", "MultiPolygon")
            .put("coordinates", coordinates)
    }

    private fun ensureClosed(ring: List<DoubleArray>): List<DoubleArray> {
        if (ring.isEmpty()) return ring
        val first = ring.first()
        val last = ring.last()
        return if (first[0] == last[0] && first[1] == last[1]) {
            ring
        } else {
            ring + listOf(doubleArrayOf(first[0], first[1]))
        }
    }
}
