package com.routefinder.fleetdriver.routing

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class GeocodeSuggestion(
    val label: String,
    val latitude: Double,
    val longitude: Double,
)

/** Pelias search via fleet proxy (`GET …/v1/proxy/pelias/v1/search`). */
class PeliasGeocoder(
    private val fleetBaseUrl: String,
    private val apiKey: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build(),
) {
    fun search(
        text: String,
        size: Int = 8,
        focusLat: Double? = null,
        focusLon: Double? = null,
    ): List<GeocodeSuggestion> {
        val trimmed = text.trim()
        if (trimmed.length < 2) return emptyList()
        val builder = "${FleetOrsConfig.peliasBaseUrl(fleetBaseUrl)}/search"
            .toHttpUrl()
            .newBuilder()
            .addQueryParameter("text", trimmed)
            .addQueryParameter("size", size.toString())
            .addQueryParameter("boundary.country", "GB")
        if (focusLat != null && focusLon != null) {
            builder.addQueryParameter("focus.point.lat", focusLat.toString())
            builder.addQueryParameter("focus.point.lon", focusLon.toString())
        }
        val auth = FleetOrsConfig.fleetProxyAuthKey(apiKey)
        val request = Request.Builder()
            .url(builder.build())
            .header("Authorization", "Bearer $auth")
            .header("Accept", "application/json")
            .header("User-Agent", FleetOrsConfig.USER_AGENT)
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            val textBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                error("geocode ${response.code}: ${textBody.take(300)}")
            }
            return parseSuggestions(JSONObject(textBody))
        }
    }

    companion object {
        fun parseSuggestions(json: JSONObject): List<GeocodeSuggestion> {
            val features = json.optJSONArray("features") ?: return emptyList()
            val out = mutableListOf<GeocodeSuggestion>()
            for (i in 0 until features.length()) {
                val feature = features.getJSONObject(i)
                val geometry = feature.optJSONObject("geometry") ?: continue
                val coords = geometry.optJSONArray("coordinates") ?: continue
                if (coords.length() < 2) continue
                val lon = coords.getDouble(0)
                val lat = coords.getDouble(1)
                val props = feature.optJSONObject("properties") ?: continue
                val label = props.optString("label").ifBlank {
                    props.optString("name")
                }
                if (label.isBlank()) continue
                out.add(GeocodeSuggestion(label = label, latitude = lat, longitude = lon))
            }
            return out
        }
    }
}

/** Reads fleet proxy metering / ORS configured flag. */
class FleetProxyStatusClient(
    private val fleetBaseUrl: String,
    private val apiKey: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build(),
) {
    data class Status(
        val orsConfigured: Boolean,
        val raw: JSONObject,
    )

    fun fetch(): Status {
        val auth = FleetOrsConfig.fleetProxyAuthKey(apiKey)
        val request = Request.Builder()
            .url(FleetOrsConfig.proxyStatusUrl(fleetBaseUrl))
            .header("Authorization", "Bearer $auth")
            .header("Accept", "application/json")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) error("proxy status ${response.code}: $text")
            val json = JSONObject(text)
            return Status(
                orsConfigured = json.optBoolean("orsConfigured", json.optBoolean("ors_configured", false)),
                raw = json,
            )
        }
    }
}
