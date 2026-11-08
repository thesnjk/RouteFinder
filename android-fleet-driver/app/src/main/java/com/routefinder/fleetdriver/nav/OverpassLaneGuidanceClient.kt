package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Overpass client for OSM `turn:lanes` tags near maneuver coordinates.
 * Prefers fleet `/v1/proxy/overpass/interpreter` when paired; mirrors iOS ``OverpassLaneGuidanceClient``.
 */
object OverpassLaneGuidanceClient {
    private const val PUBLIC_INTERPRETER = "https://overpass-api.de/api/interpreter"
    private const val DEFAULT_RADIUS_METERS = 35
    /** Cap Overpass fetches per route load (session soft budget still applies). */
    const val MAX_MANEUVERS_PER_ROUTE = 5

    private val tagPriority = listOf(
        "turn:lanes",
        "turn:lanes:forward",
        "turn:lanes:both_ways",
        "turn:lanes:backward",
        "destination:lanes",
    )

    /**
     * Prefers the richest lane tag: turn:lanes > forward > both_ways > backward > destination:lanes.
     */
    fun richestTurnLanesTag(tagMaps: List<Map<String, String>>): String? {
        var best: String? = null
        var bestScore = -1
        for (tags in tagMaps) {
            for ((rank, key) in tagPriority.withIndex()) {
                val value = tags[key]?.takeIf { it.isNotBlank() } ?: continue
                val richness = value.split("|").size * 10 - rank
                if (richness > bestScore) {
                    bestScore = richness
                    best = value
                }
            }
        }
        return best
    }

    /** Extracts element tag maps from an Overpass JSON fixture / response. */
    fun tagMapsFromOverpassJson(json: String): List<Map<String, String>> {
        val root = JSONObject(json)
        val elements = root.optJSONArray("elements") ?: return emptyList()
        return buildList {
            for (i in 0 until elements.length()) {
                val el = elements.optJSONObject(i) ?: continue
                val tags = el.optJSONObject("tags") ?: continue
                val map = mutableMapOf<String, String>()
                val keys = tags.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    map[k] = tags.optString(k)
                }
                add(map)
            }
        }
    }

    fun parseGuidanceFromOverpassJson(
        json: String,
        maneuver: TurnManeuver? = null,
    ): LaneGuidance? {
        val tag = richestTurnLanesTag(tagMapsFromOverpassJson(json)) ?: return null
        return TurnLanesParser.parse(tag, forManeuver = maneuver)
    }

    /**
     * Fetches lane guidance near a coordinate. Returns null on miss / error.
     * Records one [ApiUsageLedger] Overpass unit when a network call is made.
     */
    fun fetchLaneGuidance(
        latitude: Double,
        longitude: Double,
        maneuver: TurnManeuver? = null,
        searchRadiusMeters: Int = DEFAULT_RADIUS_METERS,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): LaneGuidance? {
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) {
            return null
        }
        val query = """
            [out:json][timeout:15];
            (
              way(around:$searchRadiusMeters,$latitude,$longitude)["turn:lanes"];
              way(around:$searchRadiusMeters,$latitude,$longitude)["turn:lanes:forward"];
              way(around:$searchRadiusMeters,$latitude,$longitude)["turn:lanes:both_ways"];
              way(around:$searchRadiusMeters,$latitude,$longitude)["turn:lanes:backward"];
              way(around:$searchRadiusMeters,$latitude,$longitude)["destination:lanes"];
            );
            out tags;
        """.trimIndent()
        return try {
            val body = "data=${URLEncoder.encode(query, Charsets.UTF_8.name())}"
            val endpoint = if (!fleetBaseUrl.isNullOrBlank()) {
                FleetOrsConfig.overpassInterpreterUrl(fleetBaseUrl)
            } else {
                PUBLIC_INTERPRETER
            }
            val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                connectTimeout = 12_000
                readTimeout = 12_000
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
            parseGuidanceFromOverpassJson(response, maneuver)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Enriches up to [MAX_MANEUVERS_PER_ROUTE] turn / roundabout instructions with OSM tags.
     * Keeps heuristic lane guidance when Overpass misses.
     */
    fun enrichInstructions(
        instructions: List<TurnInstruction>,
        route: List<LatLon>,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<TurnInstruction> {
        if (instructions.isEmpty() || route.size < 2) return instructions
        var arc = 0.0
        var fetches = 0
        return instructions.map { instruction ->
            val point = pointAlong(route, arc)
            arc += instruction.distanceMeters
            val shouldFetch = fetches < MAX_MANEUVERS_PER_ROUTE &&
                point != null &&
                instruction.maneuver != TurnManeuver.ARRIVE &&
                instruction.maneuver != TurnManeuver.DEPART &&
                instruction.maneuver != TurnManeuver.STRAIGHT
            if (!shouldFetch) {
                return@map instruction
            }
            fetches += 1
            val osm = fetchLaneGuidance(
                latitude = point!!.latitude,
                longitude = point.longitude,
                maneuver = instruction.maneuver,
                fleetBaseUrl = fleetBaseUrl,
                fleetApiKey = fleetApiKey,
            )
            if (osm != null) {
                instruction.copy(laneGuidance = osm)
            } else {
                instruction
            }
        }
    }

    private fun pointAlong(route: List<LatLon>, targetMeters: Double): LatLon? {
        if (route.isEmpty()) return null
        if (targetMeters <= 0) return route.first()
        var travelled = 0.0
        for (i in 0 until route.lastIndex) {
            val a = route[i]
            val b = route[i + 1]
            val seg = OrsResponseParser.haversineMeters(a, b)
            if (travelled + seg >= targetMeters) {
                val t = ((targetMeters - travelled) / seg).coerceIn(0.0, 1.0)
                return LatLon(
                    latitude = a.latitude + (b.latitude - a.latitude) * t,
                    longitude = a.longitude + (b.longitude - a.longitude) * t,
                )
            }
            travelled += seg
        }
        return route.last()
    }
}
