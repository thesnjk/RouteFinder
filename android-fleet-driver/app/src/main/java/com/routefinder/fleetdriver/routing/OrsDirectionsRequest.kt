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

        val options = JSONObject()
            .put(
                "profile_params",
                JSONObject().put("restrictions", restrictions),
            )
        if (avoidFeatures.length() > 0) {
            options.put("avoid_features", avoidFeatures)
        }

        return JSONObject()
            .put("coordinates", coordinates)
            .put("options", options)
            .put("instructions", true)
            .put("geometry", true)
            .put("elevation", true)
    }
}
