package com.routefinder.fleetdriver.compliance

/**
 * Formats proactive layby voice prompts and decides when to announce.
 * Mirrors iOS ``LaybyAlertFormatter``.
 */
object LaybyAlertFormatter {
    /** Default distance inside which a layby is announced once. */
    const val DEFAULT_ALERT_DISTANCE_METERS = 5_000.0

    /**
     * Returns whether a spoken layby alert should fire for this advisory.
     * Announces at most once per site id until [lastAnnouncedLaybyId] changes.
     */
    fun shouldAnnounce(
        advisory: LaybyAdvisoryEngine.Advisory,
        lastAnnouncedLaybyId: String?,
        alertDistanceMeters: Double = DEFAULT_ALERT_DISTANCE_METERS,
    ): Boolean {
        if (alertDistanceMeters <= 0) return false
        if (advisory.remainingMeters > alertDistanceMeters) return false
        return advisory.site.id != lastAnnouncedLaybyId
    }

    /** Spoken prompt when a layby enters the advisory window. */
    fun spokenPrompt(
        advisory: LaybyAdvisoryEngine.Advisory,
        estimatedArrivalSeconds: Double? = null,
    ): String {
        val eta = formattedETA(estimatedArrivalSeconds ?: etaFromRemaining(advisory.remainingMeters))
        return "Layby ahead: ${advisory.site.name} in $eta"
    }

    /** Toast after the driver marks a layby full and a replacement is chosen. */
    fun nextLaybyToast(next: LaybyAdvisoryEngine.Advisory?): String {
        if (next == null) return "No further laybys on this route"
        val eta = formattedETA(etaFromRemaining(next.remainingMeters))
        return "Next layby: ${next.site.name} in $eta"
    }

    private fun etaFromRemaining(remainingMeters: Double): Double {
        // ~72 km/h corridor assumption when live ETA is unavailable.
        return (remainingMeters / 20.0).coerceAtLeast(30.0)
    }

    private fun formattedETA(seconds: Double?): String {
        if (seconds == null || seconds <= 0) return "soon"
        val minutes = kotlin.math.round(seconds / 60.0).toInt().coerceAtLeast(1)
        if (minutes >= 60) {
            val hours = minutes / 60
            val remainder = minutes % 60
            return if (remainder == 0) {
                "$hours hour${if (hours == 1) "" else "s"}"
            } else {
                "$hours h $remainder min"
            }
        }
        return "$minutes minute${if (minutes == 1) "" else "s"}"
    }
}
