package com.routefinder.fleetdriver.hazard

import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import kotlin.math.max
import kotlin.math.min

/** Formats hazard voice prompts and selects ahead crowd hazards on the route spine. */
object HazardAheadFormatter {
    const val DEFAULT_ALERT_DISTANCE_METERS: Double = 3000.0
    private const val PROMOTE_WINDOW_MS: Long = 45L * 60L * 1000L

    val alertableTypes: Set<HazardEventType> = setOf(HazardEventType.CLOSURE, HazardEventType.TRAFFIC)

    fun shouldAnnounce(
        announcement: HazardAheadAnnouncement,
        lastAnnouncedHazardId: String?,
        alertDistanceMeters: Double = DEFAULT_ALERT_DISTANCE_METERS,
    ): Boolean {
        if (alertDistanceMeters <= 0) return false
        if (announcement.distanceRemainingMeters > alertDistanceMeters) return false
        return announcement.id != lastAnnouncedHazardId
    }

    fun spokenPrompt(announcement: HazardAheadAnnouncement): String {
        val distance = formattedDistance(announcement.distanceRemainingMeters)
        return when (announcement.type) {
            HazardEventType.CLOSURE -> "Road closure reported ahead in $distance"
            HazardEventType.TRAFFIC -> "Traffic reported ahead in $distance"
            else -> "Hazard reported ahead in $distance"
        }
    }

    fun bannerMessage(announcement: HazardAheadAnnouncement): String {
        val distance = formattedDistance(announcement.distanceRemainingMeters)
        return when (announcement.type) {
            HazardEventType.CLOSURE -> "Closure ahead in $distance"
            HazardEventType.TRAFFIC -> "Traffic ahead in $distance"
            else -> "Hazard ahead in $distance"
        }
    }

    /** Rebuilds in-memory hazard events from recent crowd closure/traffic reports. */
    fun promotedHazards(
        crowdReports: List<CrowdReport>,
        nowEpochMs: Long = System.currentTimeMillis(),
    ): List<HazardEvent> {
        val recentCutoff = nowEpochMs - PROMOTE_WINDOW_MS
        return crowdReports.mapNotNull { report ->
            if (report.type !in alertableTypes || report.createdAtEpochMs < recentCutoff) {
                null
            } else {
                HazardEvent(
                    id = "crowd-${report.id}",
                    latitude = report.latitude,
                    longitude = report.longitude,
                    radiusMeters = 90.0,
                    type = report.type,
                    severity = HazardSeverity.MODERATE,
                    validFromEpochMs = report.createdAtEpochMs,
                    validToEpochMs = report.createdAtEpochMs + PROMOTE_WINDOW_MS,
                    source = "crowd:${report.reporterId}",
                )
            }
        }
    }

    /**
     * Picks the nearest alertable crowd hazard ahead of [currentArcLengthMeters] on the route.
     * TomTom hits are fused by the caller by comparing distances.
     */
    fun nearestAhead(
        hazards: List<HazardEvent>,
        crowdReports: List<CrowdReport>,
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        nowEpochMs: Long = System.currentTimeMillis(),
        maxCrossTrackMeters: Double = 500.0,
        maxAheadMeters: Double = 20_000.0,
    ): HazardAheadAnnouncement? {
        if (route.size < 2) return null
        val candidates = mergedCandidates(hazards, crowdReports, nowEpochMs)
        var best: HazardAheadAnnouncement? = null
        var bestDistance = Double.POSITIVE_INFINITY
        for (candidate in candidates) {
            if (candidate.type !in alertableTypes) continue
            val projection = project(LatLon(candidate.latitude, candidate.longitude), route) ?: continue
            if (projection.crossTrackMeters > maxCrossTrackMeters) continue
            val remaining = projection.arcLengthMeters - currentArcLengthMeters
            if (remaining <= 0 || remaining > maxAheadMeters) continue
            if (remaining < bestDistance) {
                bestDistance = remaining
                val draft = HazardAheadAnnouncement(
                    id = candidate.id,
                    type = candidate.type,
                    distanceRemainingMeters = remaining,
                    message = "",
                    source = candidate.source,
                )
                best = draft.copy(message = bannerMessage(draft))
            }
        }
        return best
    }

    private data class Candidate(
        val id: String,
        val type: HazardEventType,
        val latitude: Double,
        val longitude: Double,
        val source: String,
    )

    private fun mergedCandidates(
        hazards: List<HazardEvent>,
        crowdReports: List<CrowdReport>,
        nowEpochMs: Long,
    ): List<Candidate> {
        val results = ArrayList<Candidate>()
        for (hazard in hazards) {
            if (hazard.type !in alertableTypes) continue
            if (nowEpochMs < hazard.validFromEpochMs || nowEpochMs > hazard.validToEpochMs) continue
            results.add(
                Candidate(hazard.id, hazard.type, hazard.latitude, hazard.longitude, hazard.source),
            )
        }
        val recentCutoff = nowEpochMs - PROMOTE_WINDOW_MS
        for (report in crowdReports) {
            if (report.type !in alertableTypes) continue
            if (report.createdAtEpochMs < recentCutoff) continue
            results.add(
                Candidate(
                    id = "crowd-${report.id}",
                    type = report.type,
                    latitude = report.latitude,
                    longitude = report.longitude,
                    source = "crowd:${report.reporterId}",
                ),
            )
        }
        return results
    }

    private data class Projection(val arcLengthMeters: Double, val crossTrackMeters: Double)

    private fun project(point: LatLon, route: List<LatLon>): Projection? {
        if (route.size < 2) return null
        val cumulative = DoubleArray(route.size)
        for (i in 0 until route.size - 1) {
            cumulative[i + 1] = cumulative[i] + OrsResponseParser.haversineMeters(route[i], route[i + 1])
        }
        var bestCross = Double.POSITIVE_INFINITY
        var bestArc = 0.0
        for (i in 0 until route.size - 1) {
            val from = route[i]
            val to = route[i + 1]
            val segment = OrsResponseParser.haversineMeters(from, to)
            if (segment <= 0.5) continue
            val t = clampProjectionParameter(point, from, to)
            val cross = crossTrackDistanceMeters(point, from, to, t)
            if (cross < bestCross) {
                bestCross = cross
                bestArc = cumulative[i] + t * segment
            }
        }
        if (bestCross == Double.POSITIVE_INFINITY) return null
        return Projection(bestArc, bestCross)
    }

    private fun clampProjectionParameter(point: LatLon, from: LatLon, to: LatLon): Double {
        val dLat = to.latitude - from.latitude
        val dLon = to.longitude - from.longitude
        val lengthSquared = dLat * dLat + dLon * dLon
        if (lengthSquared <= 1e-12) return 0.0
        val latP = point.latitude - from.latitude
        val lonP = point.longitude - from.longitude
        return max(0.0, min(1.0, (latP * dLat + lonP * dLon) / lengthSquared))
    }

    private fun crossTrackDistanceMeters(point: LatLon, from: LatLon, to: LatLon, t: Double): Double {
        val proj = LatLon(
            latitude = from.latitude + t * (to.latitude - from.latitude),
            longitude = from.longitude + t * (to.longitude - from.longitude),
        )
        return OrsResponseParser.haversineMeters(point, proj)
    }

    private fun formattedDistance(meters: Double): String {
        if (meters >= 1000) {
            val km = meters / 1000.0
            return if (km >= 10) String.format("%.0f kilometres", km) else String.format("%.1f kilometres", km)
        }
        return "${max(50, meters.toInt())} metres"
    }
}
