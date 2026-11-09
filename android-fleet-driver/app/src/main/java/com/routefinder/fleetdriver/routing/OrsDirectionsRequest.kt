package com.routefinder.fleetdriver.routing

import org.json.JSONArray
import org.json.JSONObject

/**
 * Default UK articulated HGV dimensions (metres / tonnes) used for ORS restrictions.
 * Length is bumper-to-bumper overall (ORS `length`). Trailer count selects artic vs rigid body.
 */
data class HgvVehicleProfile(
    val lengthMeters: Double = 16.5,
    val widthMeters: Double = 2.55,
    val heightMeters: Double = 4.0,
    val weightTonnes: Double = 40.0,
    val axleLoadTonnes: Double = 11.5,
    /** Number of trailers (0…3). Null means unknown / legacy (length ≥ 6 m ⇒ artic). */
    val trailerCount: Int? = 1,
    /** When true, ORS `hazmat` restriction is enabled (ADR load). */
    val hazmat: Boolean = false,
    /** Optional ORS tunnel restriction code (e.g. `B`, `C`). */
    val hazmatTunnelRestrictionCode: String? = null,
) {
    /** Clamped trailer count for UI (0 when unset). */
    val resolvedTrailerCount: Int
        get() = (trailerCount ?: 0).coerceIn(0, 3)

    /**
     * Explicit `trailerCount == 0` forces rigid. Explicit `>= 1` forces artic.
     * When `trailerCount` is null (legacy), falls back to overall length ≥ 6 m.
     */
    val usesArticulatedTrailer: Boolean
        get() = when (val count = trailerCount) {
            null -> lengthMeters >= 6.0
            else -> count.coerceIn(0, 3) >= 1
        }

    companion object {
        /** UK articulated HGV preset (44 t, 16.5 m, one trailer). */
        val ukArtic = HgvVehicleProfile(
            lengthMeters = 16.5,
            widthMeters = 2.55,
            heightMeters = 4.0,
            weightTonnes = 44.0,
            axleLoadTonnes = 11.5,
            trailerCount = 1,
        )

        /** UK rigid 26 t preset (no trailer). */
        val ukRigid = HgvVehicleProfile(
            lengthMeters = 12.0,
            widthMeters = 2.55,
            heightMeters = 4.0,
            weightTonnes = 26.0,
            axleLoadTonnes = 9.0,
            trailerCount = 0,
        )

        fun clampedTrailerCount(raw: Int?): Int? =
            raw?.coerceIn(0, 3)

        /**
         * UK bumper-to-bumper overall length suggested for a trailer count (ORS `length`).
         *
         * Ladder: rigid 12 m → artic 16.5 m → drawbar/road-train 18.75 m → EMS 25.25 m.
         */
        fun suggestedOverallLengthMeters(trailerCount: Int): Double =
            when (trailerCount.coerceIn(0, 3)) {
                0 -> 12.0
                1 -> 16.5
                2 -> 18.75
                else -> 25.25
            }
    }
}

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
