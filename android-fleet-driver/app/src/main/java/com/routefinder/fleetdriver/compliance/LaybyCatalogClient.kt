package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.nav.ApiUsageLedger
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Overpass-backed layby / rest-area catalog along a route corridor.
 * Prefers fleet `/v1/proxy/overpass/interpreter`; mirrors iOS ``LaybyCatalogService``.
 */
object LaybyCatalogClient {
    private const val PUBLIC_INTERPRETER = "https://overpass-api.de/api/interpreter"
    private const val DEFAULT_CORRIDOR_HALF_WIDTH_METERS = 1_200.0
    private const val CHUNK_SIZE = 40
    /** Soft cap on Overpass bbox POSTs per route load. */
    const val MAX_BBOXES_PER_ROUTE = 4

    /**
     * Parses Overpass JSON elements into layby sites (id / name / coordinate).
     * Safe for fixtures — no network.
     */
    fun sitesFromOverpassJson(json: String): List<LaybyAdvisoryEngine.Site> {
        val root = JSONObject(json)
        val elements = root.optJSONArray("elements") ?: return emptyList()
        val out = mutableListOf<LaybyAdvisoryEngine.Site>()
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
            val tags = el.optJSONObject("tags")
            val name = tags?.optString("name")?.takeIf { it.isNotBlank() }
                ?: tags?.optString("ref")?.takeIf { it.isNotBlank() }
                ?: "Layby"
            val siteId = "layby-$type-$id"
            if (!seen.add(siteId)) continue
            out += LaybyAdvisoryEngine.Site(
                id = siteId,
                name = name,
                coordinate = LatLon(lat, lon),
            )
        }
        return out
    }

    /**
     * Projects [sites] onto [route] and keeps those within [maxCrossTrackMeters].
     * Sorted by arc length along the route.
     */
    fun projectAndFilter(
        sites: List<LaybyAdvisoryEngine.Site>,
        route: List<LatLon>,
        maxCrossTrackMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
    ): List<LaybyAdvisoryEngine.Site> =
        projectWithArcs(sites, route, maxCrossTrackMeters).map { it.first }

    /**
     * Projects [sites] onto [route], returning (site, arcMeters) pairs within corridor.
     * Sorted by arc length along the route.
     */
    fun projectWithArcs(
        sites: List<LaybyAdvisoryEngine.Site>,
        route: List<LatLon>,
        maxCrossTrackMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
    ): List<Pair<LaybyAdvisoryEngine.Site, Double>> {
        if (route.size < 2 || sites.isEmpty()) return emptyList()
        val cumulative = cumulative(route)
        return sites.mapNotNull { site ->
            val proj = project(site.coordinate, route, cumulative) ?: return@mapNotNull null
            if (proj.second > maxCrossTrackMeters) return@mapNotNull null
            site to proj.first
        }.sortedBy { it.second }
    }

    /** Builds Overpass bbox strings (south,west,north,east) along the route. */
    fun corridorBoundingBoxes(
        route: List<LatLon>,
        corridorHalfWidthMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
        maxBoxes: Int = MAX_BBOXES_PER_ROUTE,
    ): List<String> {
        if (route.isEmpty()) return emptyList()
        val paddingDegrees = maxOf(0.02, corridorHalfWidthMeters / 111_000.0)
        val boxes = mutableListOf<String>()
        var start = 0
        while (start < route.size && boxes.size < maxBoxes) {
            val end = minOf(route.size, start + CHUNK_SIZE)
            val slice = route.subList(start, end)
            val lats = slice.map { it.latitude }
            val lons = slice.map { it.longitude }
            val south = (lats.minOrNull() ?: 0.0) - paddingDegrees
            val north = (lats.maxOrNull() ?: 0.0) + paddingDegrees
            val west = (lons.minOrNull() ?: 0.0) - paddingDegrees
            val east = (lons.maxOrNull() ?: 0.0) + paddingDegrees
            boxes += "$south,$west,$north,$east"
            if (end == route.size) break
            start = end - 1
        }
        return boxes
    }

    /**
     * Fetches laybys along [route] via fleet Overpass proxy (or public interpreter).
     * Returns empty on miss / budget / error. Prefers projected corridor hits.
     */
    fun laybysAlongRoute(
        route: List<LatLon>,
        corridorHalfWidthMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<LaybyAdvisoryEngine.Site> {
        if (route.size < 2) return emptyList()
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) {
            return emptyList()
        }
        val boxes = corridorBoundingBoxes(route, corridorHalfWidthMeters)
        if (boxes.isEmpty()) return emptyList()
        val collected = mutableListOf<LaybyAdvisoryEngine.Site>()
        for (bbox in boxes) {
            if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) break
            val json = fetchBbox(bbox, fleetBaseUrl, fleetApiKey) ?: continue
            collected += sitesFromOverpassJson(json)
        }
        return projectAndFilter(collected.distinctBy { it.id }, route, corridorHalfWidthMeters)
    }

    private fun fetchBbox(
        bbox: String,
        fleetBaseUrl: String?,
        fleetApiKey: String?,
    ): String? {
        val query = """
            [out:json][timeout:25];
            (
              node["highway"="rest_area"]($bbox);
              node["highway"="services"]($bbox);
              way["highway"="rest_area"]($bbox);
              way["highway"="services"]($bbox);
              node["highway"="layby"]($bbox);
              way["highway"="layby"]($bbox);
              node["parking"="layby"]($bbox);
              way["parking"="layby"]($bbox);
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

    private fun cumulative(route: List<LatLon>): List<Double> {
        val out = mutableListOf(0.0)
        var sum = 0.0
        for (i in 0 until route.lastIndex) {
            sum += OrsResponseParser.haversineMeters(route[i], route[i + 1])
            out += sum
        }
        return out
    }

    private fun project(
        point: LatLon,
        route: List<LatLon>,
        cumulative: List<Double>,
    ): Pair<Double, Double>? {
        var bestCross = Double.MAX_VALUE
        var bestArc = 0.0
        for (i in 0 until route.lastIndex) {
            val a = route[i]
            val b = route[i + 1]
            val dx = b.longitude - a.longitude
            val dy = b.latitude - a.latitude
            val len2 = dx * dx + dy * dy
            val t = if (len2 <= 0) 0.0 else {
                ((point.longitude - a.longitude) * dx + (point.latitude - a.latitude) * dy) / len2
            }.coerceIn(0.0, 1.0)
            val proj = LatLon(a.latitude + t * dy, a.longitude + t * dx)
            val cross = haversine(point, proj)
            val arc = cumulative[i] + t * (cumulative[i + 1] - cumulative[i])
            if (cross < bestCross) {
                bestCross = cross
                bestArc = arc
            }
        }
        return if (bestCross < Double.MAX_VALUE) bestArc to bestCross else null
    }

    private fun haversine(a: LatLon, b: LatLon): Double {
        val earth = 6_371_000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * atan2(sqrt(h), sqrt(maxOf(0.0, 1 - h)))
    }
}
