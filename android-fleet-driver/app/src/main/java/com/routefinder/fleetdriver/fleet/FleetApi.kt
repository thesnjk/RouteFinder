package com.routefinder.fleetdriver.fleet

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** REST client for RouteFinderFleetServer (C1 subset). */
class FleetApi(
    private val baseUrl: String,
    private val apiKey: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build(),
) {
    private fun url(path: String): String {
        val base = baseUrl.trimEnd('/')
        val suffix = if (path.startsWith("/")) path else "/$path"
        return base + suffix
    }

    private fun Request.Builder.auth(): Request.Builder {
        header("Accept", "application/json")
        if (apiKey.isNotBlank()) {
            header("Authorization", "Bearer ${apiKey.trim()}")
        }
        return this
    }

    fun health(): JSONObject {
        val request = Request.Builder().url(url("/health")).auth().get().build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("health ${response.code}: $body")
            return JSONObject(body)
        }
    }

    fun activeTrip(vehicleId: String): FleetTrip? {
        val request = Request.Builder()
            .url(url("/v1/vehicles/$vehicleId/active-trip"))
            .auth()
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (response.code == 204) return null
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("active-trip ${response.code}: $body")
            return parseTrip(JSONObject(body))
        }
    }

    fun getTrip(tripId: String): FleetTrip {
        val request = Request.Builder().url(url("/v1/trips/$tripId")).auth().get().build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("trip ${response.code}: $body")
            return parseTrip(JSONObject(body))
        }
    }

    fun publishSnapshot(
        trip: FleetTrip,
        status: String,
        driverLatitude: Double? = null,
        driverLongitude: Double? = null,
        driverLocationRecordedAt: String? = null,
        physicsETASeconds: Double? = null,
        latestInspectionSummary: JSONObject? = null,
    ): FleetTrip {
        val media = "application/json; charset=utf-8".toMediaType()
        val payload = trip.toSnapshotJson(
            statusOverride = status,
            driverLatitude = driverLatitude,
            driverLongitude = driverLongitude,
            driverLocationRecordedAt = driverLocationRecordedAt,
            physicsETASecondsOverride = physicsETASeconds,
            latestInspectionSummary = latestInspectionSummary,
        )
        val request = Request.Builder()
            .url(url("/v1/trips/${trip.id}/snapshot"))
            .auth()
            .put(payload.toString().toRequestBody(media))
            .build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("snapshot ${response.code}: $body")
            return parseTrip(JSONObject(body))
        }
    }

    fun vehiclesForOrg(orgId: String): List<FleetVehicle> {
        val request = Request.Builder()
            .url(url("/v1/orgs/$orgId/vehicles"))
            .auth()
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("vehicles ${response.code}: $body")
            val arr = org.json.JSONArray(body)
            return buildList {
                for (i in 0 until arr.length()) {
                    add(parseVehicle(arr.getJSONObject(i)))
                }
            }
        }
    }

    fun eventsUrl(vehicleId: String): String = url("/v1/vehicles/$vehicleId/events")

    fun authorizedRequest(url: String): Request =
        Request.Builder().url(url).auth().get().build()
}
