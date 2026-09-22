package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import com.routefinder.fleetdriver.routing.LatLon
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt
import org.json.JSONObject

/**
 * Overpass-backed maxheight / maxweight / maxwidth probe along a route corridor.
 */
object ClearanceCorridorProbe {
    const val MAX_ELEMENTS = 80
    const val DEFAULT_CORRIDOR_HALF_WIDTH_METERS = 120.0
    const val DEFAULT_AHEAD_METERS = 25_000.0

    data class ClearanceRestrictionHit(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val arcLengthAlongRouteMeters: Double? = null,
        val maxHeightMeters: Double? = null,
        val maxWeightTonnes: Double? = null,
        val maxWidthMeters: Double? = null,
        val label: String,
    )

    fun advisories(
        hits: List<ClearanceRestrictionHit>,
        profile: HgvVehicleProfile,
        currentArcLengthMeters: Double,
    ): List<PredictiveRiskEngine.Advisory> {
        val items = mutableListOf<PredictiveRiskEngine.Advisory>()
        for (hit in hits) {
            val remaining = max(0.0, (hit.arcLengthAlongRouteMeters ?: 0.0) - currentArcLengthMeters)
            if (remaining <= 0 && hit.arcLengthAlongRouteMeters != null) continue
            val reasons = mutableListOf<String>()
            var severe = false
            val maxH = hit.maxHeightMeters
            if (maxH != null && profile.heightMeters > maxH) {
                reasons += "height ${"%.1f".format(profile.heightMeters)}m > limit ${"%.1f".format(maxH)}m"
                severe = true
            }
            val maxW = hit.maxWidthMeters
            if (maxW != null && profile.widthMeters > maxW) {
                reasons += "width ${"%.2f".format(profile.widthMeters)}m > limit ${"%.2f".format(maxW)}m"
                severe = true
            }
            val maxWeight = hit.maxWeightTonnes
            if (maxWeight != null && profile.weightTonnes > maxWeight) {
                reasons += "weight ${"%.1f".format(profile.weightTonnes)}t > limit ${"%.1f".format(maxWeight)}t"
                severe = true
            }
            if (reasons.isEmpty()) continue
            val distance = if (hit.arcLengthAlongRouteMeters == null) 2_000.0 else max(200.0, remaining)
            items += PredictiveRiskEngine.Advisory(
                id = "clearance-${hit.id}",
                kind = PredictiveRiskEngine.Kind.CLEARANCE,
                severity = if (severe) PredictiveRiskEngine.Severity.SEVERE else PredictiveRiskEngine.Severity.CAUTION,
                distanceRemainingMeters = distance,
                message = "Clearance: ${hit.label} — ${reasons.joinToString("; ")}",
                source = "clearanceOverpass",
            )
        }
        return items
    }

    fun advisoriesAlongRoute(
        route: List<LatLon>,
        profile: HgvVehicleProfile,
        currentArcLengthMeters: Double,
        aheadMeters: Double = DEFAULT_AHEAD_METERS,
        corridorHalfWidthMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<PredictiveRiskEngine.Advisory> {
        val hits = queryAlongRoute(
            route = route,
            aheadMeters = aheadMeters,
            fromArcLengthMeters = currentArcLengthMeters,
            corridorHalfWidthMeters = corridorHalfWidthMeters,
            fleetBaseUrl = fleetBaseUrl,
            fleetApiKey = fleetApiKey,
        )
        return advisories(hits, profile, currentArcLengthMeters)
    }

    const val OFF_ROUTE_CROSS_TRACK_THRESHOLD_METERS = 75.0
    const val DEFAULT_HEADING_AHEAD_METERS = 3_000.0
    const val OFF_ROUTE_REFRESH_INTERVAL_MS = 90_000L

    private var lastOffRouteRefreshMs: Long? = null

    /** Builds a short polyline ahead of [origin] along [bearingDegrees]. */
    fun headingCorridor(
        from: LatLon,
        bearingDegrees: Double,
        lengthMeters: Double = DEFAULT_HEADING_AHEAD_METERS,
        stepMeters: Double = 250.0,
    ): List<LatLon> {
        if (lengthMeters <= 0 || stepMeters <= 0) return listOf(from)
        val points = mutableListOf(from)
        var travelled = 0.0
        while (travelled < lengthMeters) {
            travelled = minOf(lengthMeters, travelled + stepMeters)
            points += destinationPoint(from, bearingDegrees, travelled)
        }
        return points
    }

    fun isOffRoute(
        point: LatLon,
        route: List<LatLon>,
        thresholdMeters: Double = OFF_ROUTE_CROSS_TRACK_THRESHOLD_METERS,
    ): Pair<Boolean, Double> {
        val projection = project(point, route) ?: return true to (thresholdMeters + 1)
        return (projection.second > thresholdMeters) to projection.second
    }

    fun advisoriesAlongHeading(
        from: LatLon,
        bearingDegrees: Double,
        profile: HgvVehicleProfile,
        aheadMeters: Double = DEFAULT_HEADING_AHEAD_METERS,
        corridorHalfWidthMeters: Double = DEFAULT_CORRIDOR_HALF_WIDTH_METERS,
        force: Boolean = false,
        nowMs: Long = System.currentTimeMillis(),
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<PredictiveRiskEngine.Advisory> {
        if (!force) {
            val last = lastOffRouteRefreshMs
            if (last != null && nowMs - last < OFF_ROUTE_REFRESH_INTERVAL_MS) {
                return emptyList()
            }
        }
        val corridor = headingCorridor(from, bearingDegrees, aheadMeters)
        val hits = queryAlongRoute(
            route = corridor,
            aheadMeters = aheadMeters,
            fromArcLengthMeters = 0.0,
            corridorHalfWidthMeters = corridorHalfWidthMeters,
            fleetBaseUrl = fleetBaseUrl,
            fleetApiKey = fleetApiKey,
        )
        lastOffRouteRefreshMs = nowMs
        return advisories(hits, profile, currentArcLengthMeters = 0.0).map { advisory ->
            advisory.copy(
                message = if (advisory.message.startsWith("Off-route ")) {
                    advisory.message
                } else {
                    "Off-route ${advisory.message}"
                },
                source = "clearanceOverpassOffRoute",
            )
        }
    }

    fun destinationPoint(from: LatLon, bearingDegrees: Double, distanceMeters: Double): LatLon {
        val earth = 6_371_000.0
        val angular = distanceMeters / earth
        val bearing = Math.toRadians(bearingDegrees)
        val lat1 = Math.toRadians(from.latitude)
        val lon1 = Math.toRadians(from.longitude)
        val lat2 = kotlin.math.asin(
            sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing),
        )
        val lon2 = lon1 + atan2(
            sin(bearing) * sin(angular) * cos(lat1),
            cos(angular) - sin(lat1) * cos(lat2),
        )
        return LatLon(Math.toDegrees(lat2), Math.toDegrees(lon2))
    }

    fun queryAlongRoute(
        route: List<LatLon>,
        aheadMeters: Double,
        fromArcLengthMeters: Double,
        corridorHalfWidthMeters: Double,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<ClearanceRestrictionHit> {
        if (route.size < 2) return emptyList()
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OVERPASS)) {
            return emptyList()
        }
        val bbox = corridorBoundingBox(route, paddingDegrees = 0.025)
        val raw = fetchRestrictions(bbox, fleetBaseUrl, fleetApiKey)
        ApiUsageLedger.record(ApiUsageLedger.Provider.OVERPASS)
        val projected = projectAndFilter(raw, route, corridorHalfWidthMeters)
        val end = fromArcLengthMeters + aheadMeters
        return projected.filter { hit ->
            val arc = hit.arcLengthAlongRouteMeters
            arc == null || (arc >= fromArcLengthMeters - 500 && arc <= end)
        }.sortedBy { it.arcLengthAlongRouteMeters ?: 0.0 }
    }

    fun parseFixture(json: String): List<ClearanceRestrictionHit> {
        val root = JSONObject(json)
        val elements = root.optJSONArray("elements") ?: return emptyList()
        return buildList {
            for (i in 0 until minOf(MAX_ELEMENTS, elements.length())) {
                hitFromElement(elements.getJSONObject(i))?.let { add(it) }
            }
        }
    }

    fun parseMeters(raw: String?): Double? {
        val text = raw?.trim()?.lowercase().orEmpty()
        if (text.isEmpty() || text == "default" || text == "none") return null
        text.replace("m", "").trim().toDoubleOrNull()?.let { return it }
        if (text.contains("'")) {
            val cleaned = text.replace("\"", "")
            val parts = cleaned.split("'")
            val feet = parts.getOrNull(0)?.toDoubleOrNull() ?: 0.0
            val inches = parts.getOrNull(1)?.toDoubleOrNull() ?: 0.0
            return (feet * 12 + inches) * 0.0254
        }
        return null
    }

    fun parseTonnes(raw: String?): Double? {
        val text = raw?.trim()?.lowercase().orEmpty()
        if (text.isEmpty()) return null
        if (text.contains("kg")) {
            return text.replace("kg", "").trim().toDoubleOrNull()?.div(1_000.0)
        }
        return text.replace("t", "").trim().toDoubleOrNull()
    }

    private fun hitFromElement(element: JSONObject): ClearanceRestrictionHit? {
        val tags = element.optJSONObject("tags") ?: return null
        val center = element.optJSONObject("center")
        val lat = when {
            element.has("lat") -> element.optDouble("lat")
            center != null -> center.optDouble("lat")
            else -> return null
        }
        val lon = when {
            element.has("lon") -> element.optDouble("lon")
            center != null -> center.optDouble("lon")
            else -> return null
        }
        val maxHeight = parseMeters(tags.optString("maxheight").takeIf { it.isNotBlank() })
        val maxWidth = parseMeters(tags.optString("maxwidth").takeIf { it.isNotBlank() })
        val maxWeight = parseTonnes(
            tags.optString("maxweight").takeIf { it.isNotBlank() }
                ?: tags.optString("maxweightrating").takeIf { it.isNotBlank() },
        )
        if (maxHeight == null && maxWidth == null && maxWeight == null) return null
        val label = tags.optString("name").takeIf { it.isNotBlank() }
            ?: tags.optString("bridge").takeIf { it.isNotBlank() }
            ?: "restriction"
        return ClearanceRestrictionHit(
            id = "${element.optString("type")}/${element.optLong("id")}",
            latitude = lat,
            longitude = lon,
            maxHeightMeters = maxHeight,
            maxWeightTonnes = maxWeight,
            maxWidthMeters = maxWidth,
            label = label,
        )
    }

    private fun fetchRestrictions(
        bbox: String,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<ClearanceRestrictionHit> {
        val query = """
            [out:json][timeout:25];
            (
              node["maxheight"]($bbox);
              way["maxheight"]($bbox);
              node["maxweight"]($bbox);
              way["maxweight"]($bbox);
              node["maxwidth"]($bbox);
              way["maxwidth"]($bbox);
            );
            out center tags;
        """.trimIndent()
        return try {
            val body = "data=${URLEncoder.encode(query, Charsets.UTF_8.name())}"
            val endpoint = if (!fleetBaseUrl.isNullOrBlank()) {
                FleetOrsConfig.overpassInterpreterUrl(fleetBaseUrl)
            } else {
                "https://overpass-api.de/api/interpreter"
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
            parseFixture(response)
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun corridorBoundingBox(route: List<LatLon>, paddingDegrees: Double): String {
        val lats = route.map { it.latitude }
        val lons = route.map { it.longitude }
        val south = (lats.minOrNull() ?: 0.0) - paddingDegrees
        val north = (lats.maxOrNull() ?: 0.0) + paddingDegrees
        val west = (lons.minOrNull() ?: 0.0) - paddingDegrees
        val east = (lons.maxOrNull() ?: 0.0) + paddingDegrees
        return "$south,$west,$north,$east"
    }

    private fun projectAndFilter(
        hits: List<ClearanceRestrictionHit>,
        route: List<LatLon>,
        maxCrossTrackMeters: Double,
    ): List<ClearanceRestrictionHit> =
        hits.mapNotNull { hit ->
            val projection = project(LatLon(hit.latitude, hit.longitude), route) ?: return@mapNotNull null
            if (projection.second > maxCrossTrackMeters) return@mapNotNull null
            hit.copy(arcLengthAlongRouteMeters = projection.first)
        }

    private fun project(point: LatLon, route: List<LatLon>): Pair<Double, Double>? {
        if (route.size < 2) return null
        var bestCross = Double.MAX_VALUE
        var bestArc = 0.0
        var cumulative = 0.0
        for (i in 0 until route.lastIndex) {
            val a = route[i]
            val b = route[i + 1]
            val segment = haversineMeters(a, b)
            val t = projectT(point, a, b).coerceIn(0.0, 1.0)
            val cross = crossTrack(point, a, b, t)
            val arc = cumulative + t * segment
            if (cross < bestCross) {
                bestCross = cross
                bestArc = arc
            }
            cumulative += segment
        }
        return bestArc to bestCross
    }

    private fun projectT(point: LatLon, from: LatLon, to: LatLon): Double {
        val dx = to.longitude - from.longitude
        val dy = to.latitude - from.latitude
        val len2 = dx * dx + dy * dy
        if (len2 <= 0) return 0.0
        return ((point.longitude - from.longitude) * dx + (point.latitude - from.latitude) * dy) / len2
    }

    private fun crossTrack(point: LatLon, from: LatLon, to: LatLon, t: Double): Double {
        val proj = LatLon(
            latitude = from.latitude + t * (to.latitude - from.latitude),
            longitude = from.longitude + t * (to.longitude - from.longitude),
        )
        return haversineMeters(point, proj)
    }

    private fun haversineMeters(a: LatLon, b: LatLon): Double {
        val earth = 6_371_000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * atan2(sqrt(h), sqrt(max(0.0, 1 - h)))
    }
}
