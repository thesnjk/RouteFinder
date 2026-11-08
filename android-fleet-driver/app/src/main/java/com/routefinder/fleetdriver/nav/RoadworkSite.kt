package com.routefinder.fleetdriver.nav

/**
 * A roadworks / construction site projected onto the active route corridor.
 * Mirrors iOS ``RoadworkSite``.
 */
data class RoadworkSite(
    val id: String,
    val label: String = "Roadworks",
    val latitude: Double,
    val longitude: Double,
    /** Arc length along the active route spine in meters, when projected. */
    val arcLengthAlongRouteMeters: Double? = null,
)

/** Formats roadworks-ahead banner copy for the predictive fuse / HUD. */
object RoadworksAheadFormatter {
    const val DEFAULT_MAX_AHEAD_METERS = 32_000.0

    /**
     * Banner text for the nearest roadworks site ahead (metric, Android cab).
     * Returns null when the site has no arc or is behind the vehicle.
     */
    fun bannerMessage(site: RoadworkSite, currentArcLengthMeters: Double): String? {
        val arc = site.arcLengthAlongRouteMeters ?: return null
        val remaining = arc - currentArcLengthMeters
        if (remaining <= 0) return null
        val km = remaining / 1_000.0
        return if (km >= 1.0) {
            String.format("Roadworks in %.1f km along route", km)
        } else {
            "Roadworks ahead along route"
        }
    }

    /** Remaining meters to [site] along the route, or null if behind / unprojected. */
    fun remainingMeters(site: RoadworkSite, currentArcLengthMeters: Double): Double? {
        val arc = site.arcLengthAlongRouteMeters ?: return null
        val remaining = arc - currentArcLengthMeters
        return remaining.takeIf { it > 0 }
    }

    /** Picks the nearest roadworks site ahead on the route. */
    fun nearestAhead(
        sites: List<RoadworkSite>,
        currentArcLengthMeters: Double,
        maxAheadMeters: Double = DEFAULT_MAX_AHEAD_METERS,
    ): RoadworkSite? {
        return sites.mapNotNull { site ->
            val remaining = remainingMeters(site, currentArcLengthMeters) ?: return@mapNotNull null
            if (remaining > maxAheadMeters) return@mapNotNull null
            site to remaining
        }.minByOrNull { it.second }?.first
    }
}
