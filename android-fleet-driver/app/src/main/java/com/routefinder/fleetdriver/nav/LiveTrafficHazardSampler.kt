package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.LatLon
import kotlin.math.max

/**
 * Samples TomTom flow segments ahead of the vehicle during live navigation (Ph36 parity).
 * Mirrors iOS ``LiveTrafficHazardSampler`` — planning / fuse aid, not a legal traffic authority.
 */
object LiveTrafficHazardSampler {
    /** Default arc-length offsets ahead of the vehicle to probe (meters). */
    val AHEAD_SAMPLE_OFFSETS_METERS = listOf(2_000.0, 5_000.0, 8_000.0)

    /** Minimum interval between live TomTom hazard polls. */
    const val POLL_INTERVAL_MS = 30_000L

    /** Speed/free-flow ratio at or below this counts as standstill (reroute-worthy). */
    const val STANDSTILL_RATIO = 0.25

    data class Hit(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val arcLengthAlongRouteMeters: Double,
        val isRoadClosed: Boolean,
        val message: String,
        val remainingMeters: Double,
        val severe: Boolean,
    )

    data class FlowSample(
        val currentSpeedKmh: Double,
        val freeFlowSpeedKmh: Double,
        val roadClosed: Boolean,
    )

    /** Returns whether another TomTom hazard poll is allowed. */
    fun shouldPoll(lastSampleMs: Long?, nowMs: Long = System.currentTimeMillis()): Boolean {
        if (lastSampleMs == null) return true
        return nowMs - lastSampleMs >= POLL_INTERVAL_MS
    }

    /**
     * Coordinates to sample ahead of the current arc length on the route spine.
     * Reuses [ForecastRiskSampler.samplePointsAhead] geometry.
     */
    fun samplePointsAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        offsetsMeters: List<Double> = AHEAD_SAMPLE_OFFSETS_METERS,
    ): List<Pair<LatLon, Double>> =
        ForecastRiskSampler.samplePointsAhead(route, currentArcLengthMeters, offsetsMeters)

    /**
     * Builds a hazard hit when flow indicates road closure or standstill.
     * Aligns with iOS ``isRerouteWorthy`` spirit and Android forecast standstill ratio.
     */
    fun hazardHit(
        flow: FlowSample,
        sample: LatLon,
        arcLengthMeters: Double,
        currentArcLengthMeters: Double,
    ): Hit? {
        val remaining = arcLengthMeters - currentArcLengthMeters
        if (remaining <= 0) return null
        val ratio = if (flow.freeFlowSpeedKmh > 0) {
            flow.currentSpeedKmh / flow.freeFlowSpeedKmh
        } else {
            1.0
        }
        val worthy = flow.roadClosed || ratio < STANDSTILL_RATIO
        if (!worthy) return null
        val id = "tomtom-${sample.latitude}-${sample.longitude}-${arcLengthMeters.toInt()}"
        val distanceLabel = formatDistance(remaining)
        val message = if (flow.roadClosed) {
            "Road closed ahead in $distanceLabel"
        } else {
            "Live traffic delay ahead in $distanceLabel"
        }
        return Hit(
            id = id,
            latitude = sample.latitude,
            longitude = sample.longitude,
            arcLengthAlongRouteMeters = arcLengthMeters,
            isRoadClosed = flow.roadClosed,
            message = message,
            remainingMeters = remaining,
            severe = flow.roadClosed || ratio < 0.15,
        )
    }

    /**
     * Polls TomTom at ahead sample points and returns the nearest worthy hit.
     * Uses fleet TomTom proxy when [fleetBaseUrl] is set; otherwise direct API key.
     */
    fun sampleAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        apiKey: String,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
        offsetsMeters: List<Double> = AHEAD_SAMPLE_OFFSETS_METERS,
    ): Hit? {
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.TOMTOM_FLOW)) {
            return null
        }
        val points = samplePointsAhead(route, currentArcLengthMeters, offsetsMeters)
        if (points.isEmpty()) return null

        var nearest: Hit? = null
        var nearestDistance = Double.POSITIVE_INFINITY

        for ((coord, arc) in points) {
            val triple = ForecastRiskSampler.fetchTomTomFlow(
                coord = coord,
                apiKey = apiKey,
                fleetBaseUrl = fleetBaseUrl,
                fleetApiKey = fleetApiKey,
            ) ?: continue
            val flow = FlowSample(
                currentSpeedKmh = triple.first,
                freeFlowSpeedKmh = triple.second,
                roadClosed = triple.third,
            )
            val hit = hazardHit(
                flow = flow,
                sample = coord,
                arcLengthMeters = arc,
                currentArcLengthMeters = currentArcLengthMeters,
            ) ?: continue
            if (hit.remainingMeters < nearestDistance) {
                nearestDistance = hit.remainingMeters
                nearest = hit
            }
        }

        if (points.isNotEmpty()) {
            ApiUsageLedger.record(ApiUsageLedger.Provider.TOMTOM_FLOW)
        }
        return nearest
    }

    /** Picks the nearest hit among candidates (pure helper for tests). */
    fun nearestHit(hits: List<Hit>): Hit? =
        hits.minByOrNull { it.remainingMeters }

    private fun formatDistance(meters: Double): String {
        val m = max(0.0, meters)
        return if (m >= 1_000) {
            String.format("%.1f km", m / 1_000.0)
        } else {
            "${m.toInt()} m"
        }
    }
}
