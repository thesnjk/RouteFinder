package com.routefinder.fleetdriver.routing

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** ORS HGV directions via fleet proxy (`POST …/directions/driving-hgv/geojson`). */
class OrsRoutingClient(
    private val fleetBaseUrl: String,
    private val apiKey: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build(),
) {
    fun route(
        originLon: Double,
        originLat: Double,
        destinationLon: Double,
        destinationLat: Double,
        via: List<Pair<Double, Double>> = emptyList(),
        vehicle: HgvVehicleProfile = HgvVehicleProfile(),
    ): OrsRouteResult {
        val body = OrsDirectionsRequest.buildJson(
            originLon = originLon,
            originLat = originLat,
            destinationLon = destinationLon,
            destinationLat = destinationLat,
            via = via,
            vehicle = vehicle,
        )
        val media = "application/json; charset=utf-8".toMediaType()
        val auth = FleetOrsConfig.fleetProxyAuthKey(apiKey)
        val request = Request.Builder()
            .url(FleetOrsConfig.hgvDirectionsUrl(fleetBaseUrl))
            .header("Authorization", "Bearer $auth")
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .header("User-Agent", FleetOrsConfig.USER_AGENT)
            .post(body.toString().toRequestBody(media))
            .build()
        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                error("ORS route ${response.code}: ${text.take(400)}")
            }
            return OrsResponseParser.parse(JSONObject(text))
        }
    }
}
