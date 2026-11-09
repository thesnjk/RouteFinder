package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.nav.ApiUsageLedger
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.LatLon
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Overpass-backed truck corridor POIs (HGV fuel, weighbridge, overnight parking).
 * Mirrors iOS ``OverpassTruckPoiRepository``; fuel subset still feeds Ph32 card matching.
 */
object FuelPoiCatalogClient {
    private const val PUBLIC_INTERPRETER = "https://overpass-api.de/api/interpreter"

    /**
     * Parses Overpass JSON elements into corridor truck POIs (fuel / weigh / parking).
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
            val kind = classify(tags) ?: continue
            val name = tags.optString("name").takeIf { it.isNotBlank() }
                ?: tags.optString("brand").takeIf { it.isNotBlank() }
                ?: defaultLabel(kind)
            val poiId = "${kindPrefix(kind)}-$type-$id"
            if (!seen.add(poiId)) continue
            out += TruckFuelPoi(
                id = poiId,
                label = name,
                latitude = lat,
                longitude = lon,
                amenities = amenitiesFrom(tags, kind),
                kind = kind,
            )
        }
        return out
    }

    /**
     * Fetches HGV fuel POIs along [route] (fuel subset only) for fuel-card matching.
     */
    fun fuelPoisAlongRoute(
        route: List<LatLon>,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<TruckFuelPoi> =
        truckPoisAlongRoute(route, fleetBaseUrl, fleetApiKey)
            .filter { it.kind == TruckFuelPoi.Kind.HIGH_FLOW_DIESEL }

    /**
     * Fetches fuel + weigh + overnight parking POIs along [route] via fleet Overpass proxy
     * (or public interpreter). Reuses layby corridor bboxes; empty on miss / budget / error.
     */
    fun truckPoisAlongRoute(
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

    /**
     * Classifies OSM tags into a corridor kind, or null when the element should be skipped
     * (e.g. non-HGV fuel).
     */
    fun classify(tags: JSONObject): TruckFuelPoi.Kind? {
        val manMade = tags.optString("man_made")
        val highway = tags.optString("highway")
        if (manMade == "weighbridge" || highway == "weigh_station") {
            return TruckFuelPoi.Kind.WEIGH_STATION
        }
        if (tags.optString("amenity") == "fuel") {
            return if (isHgvFuel(tags)) TruckFuelPoi.Kind.HIGH_FLOW_DIESEL else null
        }
        val amenity = tags.optString("amenity")
        if (amenity == "parking") {
            val access = tags.optString("access")
            val supervised = tags.optString("supervised")
            val hgv = tags.optString("hgv").lowercase()
            val truck = tags.optString("truck").lowercase()
            if (access == "customers" || supervised == "yes" ||
                hgv == "yes" || hgv == "designated" || truck == "yes"
            ) {
                return TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING
            }
            return TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING
        }
        if (highway == "rest_area" || highway == "services") {
            // Laybys are owned by LaybyCatalogClient; skip duplicate rest/services here.
            return null
        }
        return null
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

    private fun amenitiesFrom(tags: JSONObject, kind: TruckFuelPoi.Kind): Set<String> {
        val out = mutableSetOf<String>()
        when (kind) {
            TruckFuelPoi.Kind.HIGH_FLOW_DIESEL -> out += "fuel"
            TruckFuelPoi.Kind.WEIGH_STATION -> out += "weigh"
            TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING -> out += "parking"
            TruckFuelPoi.Kind.OTHER -> Unit
        }
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

    private fun defaultLabel(kind: TruckFuelPoi.Kind): String = when (kind) {
        TruckFuelPoi.Kind.HIGH_FLOW_DIESEL -> "HGV fuel"
        TruckFuelPoi.Kind.WEIGH_STATION -> "Weighbridge"
        TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING -> "Truck parking"
        TruckFuelPoi.Kind.OTHER -> "Truck stop"
    }

    private fun kindPrefix(kind: TruckFuelPoi.Kind): String = when (kind) {
        TruckFuelPoi.Kind.HIGH_FLOW_DIESEL -> "fuel"
        TruckFuelPoi.Kind.WEIGH_STATION -> "weigh"
        TruckFuelPoi.Kind.OVERNIGHT_SECURE_PARKING -> "park"
        TruckFuelPoi.Kind.OTHER -> "truck"
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
              node["amenity"="parking"]["hgv"~"yes|designated"]($bbox);
              node["amenity"="parking"]["truck"="yes"]($bbox);
              node["man_made"="weighbridge"]($bbox);
              node["highway"="weigh_station"]($bbox);
              way["man_made"="weighbridge"]($bbox);
              way["highway"="weigh_station"]($bbox);
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
