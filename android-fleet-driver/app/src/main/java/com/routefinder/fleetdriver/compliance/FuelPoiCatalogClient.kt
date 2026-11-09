package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.nav.ApiUsageLedger
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.LatLon
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Overpass-backed HGV / high-flow diesel fuel POIs along a route corridor.
 * Mirrors iOS ``OverpassTruckPoiRepository`` fuel subset for Ph32 fuel-card matching.
 */
object FuelPoiCatalogClient {
    private const val PUBLIC_INTERPRETER = "https://overpass-api.de/api/interpreter"

    /**
     * Parses Overpass JSON elements into high-flow diesel fuel POIs.
     * Safe for fixtures — no network.
     */
    fun poisFromOverpassJson(json: String): List<TruckFuelPoi> {
        val root = JSONObject(json)
        val elements = root.optJSONArray("elements") ?: return emptyList()
        val out = mutableListOf<TruckFuelPoi>()
        val seen = mutableSetOf<String>()
        for (i in 0 until elements.length()) {
            val el = elements.optJSONObject(i) ?: continue
            val type = el.optString("type", "node")
            val id = el.optLong("id", -1L)
            if (id < 0) continue
            val center = el.optJSONObject("center")
            val lat = when {
                el.has("lat") -> el.optDouble("lat")
                center != null -> center.optDouble("lat")
                else -> continue
            }
            val lon = when {
                el.has("lon") -> el.optDouble("lon")
                center != null -> center.optDouble("lon")
                else -> continue
            }
            if (lat.isNaN() || lon.isNaN()) continue
            val tags = el.optJSONObject("tags") ?: continue
            if (!isHgvFuel(tags)) continue
            val name = tags.optString("name").takeIf { it.isNotBlank() }
                ?: tags.optString("brand").takeIf { it.isNotBlank() }
                ?: "HGV fuel"
            val poiId = "fuel-$type-$id"
            if (!seen.add(poiId)) continue
            out += TruckFuelPoi(
                id = poiId,
                label = name,
                latitude = lat,
                longitude = lon,
                amenities = amenitiesFrom(tags),
                kind = TruckFuelPoi.Kind.HIGH_FLOW_DIESEL,
            )
        }
        return out
    }

    /**
     * Fetches HGV fuel POIs along [route] via fleet Overpass proxy (or public interpreter).
     * Reuses layby corridor bboxes; returns empty on miss / budget / error.
     */
    fun fuelPoisAlongRoute(
        route: List<LatLon>,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<TruckFuelPoi> {
        if (route.size < 2) return emptyList()
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) {
            return emptyList()
        }
        val boxes = LaybyCatalogClient.corridorBoundingBoxes(route)
        if (boxes.isEmpty()) return emptyList()
        val collected = mutableListOf<TruckFuelPoi>()
        for (bbox in boxes) {
            if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) break
            val json = fetchBbox(bbox, fleetBaseUrl, fleetApiKey) ?: continue
            collected += poisFromOverpassJson(json)
        }
        val projected = LaybyCatalogClient.projectAndFilter(
            sites = collected.map {
                LaybyAdvisoryEngine.Site(
                    id = it.id,
                    name = it.label,
                    coordinate = LatLon(it.latitude, it.longitude),
                )
            },
            route = route,
        )
        val byId = collected.associateBy { it.id }
        return projected.mapNotNull { byId[it.id] }.distinctBy { it.id }
    }

    private fun isHgvFuel(tags: JSONObject): Boolean {
        if (tags.optString("amenity") != "fuel") return false
        val hgv = tags.optString("hgv").lowercase()
        if (hgv == "yes" || hgv == "designated") return true
        if (tags.optString("fuel:hgv").equals("yes", ignoreCase = true)) return true
        if (tags.optString("truck").equals("yes", ignoreCase = true)) return true
        val name = tags.optString("name")
        return name.contains("Truck", ignoreCase = true) ||
            name.contains("HGV", ignoreCase = true) ||
            name.contains("lorry", ignoreCase = true)
    }

    private fun amenitiesFrom(tags: JSONObject): Set<String> {
        val out = mutableSetOf("fuel")
        val brand = tags.optString("brand").trim()
        if (brand.isNotEmpty()) {
            out += "brand:${brand.lowercase()}"
        }
        val hgv = tags.optString("hgv")
        if (hgv.equals("yes", ignoreCase = true) || hgv.equals("designated", ignoreCase = true)) {
            out += "hgv"
        }
        return out
    }

    private fun fetchBbox(
        bbox: String,
        fleetBaseUrl: String?,
        fleetApiKey: String?,
    ): String? {
        val query = """
            [out:json][timeout:25];
            (
              node["amenity"="fuel"]["hgv"~"yes|designated"]($bbox);
              node["amenity"="fuel"]["fuel:hgv"="yes"]($bbox);
              node["amenity"="fuel"]["truck"="yes"]($bbox);
              node["amenity"="fuel"]["name"~"Truck|HGV|lorry",i]($bbox);
              way["amenity"="fuel"]["hgv"~"yes|designated"]($bbox);
              way["amenity"="fuel"]["fuel:hgv"="yes"]($bbox);
            );
            out center tags;
        """.trimIndent()
        return try {
            val body = "data=${URLEncoder.encode(query, Charsets.UTF_8.name())}"
            val endpoint = if (!fleetBaseUrl.isNullOrBlank()) {
                FleetOrsConfig.overpassInterpreterUrl(fleetBaseUrl)
            } else {
                PUBLIC_INTERPRETER
            }
            val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 20_000
                requestMethod = "POST"
                doOutput = true
                setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                if (!fleetBaseUrl.isNullOrBlank()) {
                    setRequestProperty(
                        "Authorization",
                        "Bearer ${FleetOrsConfig.fleetProxyAuthKey(fleetApiKey)}",
                    )
                }
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val response = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()
            ApiUsageLedger.record(ApiUsageLedger.Provider.OVERPASS)
            response
        } catch (_: Exception) {
            null
        }
    }
}
