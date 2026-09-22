package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.fleet.FleetTripStop
import com.routefinder.fleetdriver.fleet.StopTimeWindow
import java.time.Instant
import java.time.format.DateTimeParseException
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Evaluates physics ETA against dispatch stop time windows (iOS ``TimeWindowRiskEvaluator`` parity).
 */
object TimeWindowRiskEvaluator {
    const val LATE_SLACK_SECONDS = 15 * 60.0

    data class Result(val message: String, val distanceMeters: Double)

    fun advisory(
        windows: List<StopTimeWindow>,
        stops: List<FleetTripStop>,
        physicsEtaSeconds: Double?,
        now: Instant = Instant.now(),
    ): Result? {
        val eta = physicsEtaSeconds ?: return null
        if (eta <= 0) return null
        val projectedArrival = now.plusSeconds(eta.toLong())
        var worstLate: Pair<String, Double>? = null

        for (window in windows) {
            val latest = parseInstant(window.latestArrival) ?: continue
            val lateBy = (projectedArrival.epochSecond - latest.epochSecond).toDouble()
            if (lateBy <= LATE_SLACK_SECONDS) continue
            val label = stops.firstOrNull { it.id == window.stopId }?.label ?: "stop"
            val minutesLate = (lateBy / 60.0).roundToInt()
            val message = "Projected late to $label by $minutesLate min (dispatch window)"
            if (worstLate == null || lateBy > worstLate.second) {
                worstLate = message to lateBy
            }
        }

        val worst = worstLate ?: return null
        val distance = max(500.0, eta * (60_000.0 / 3_600.0))
        return Result(worst.first, min(distance, 50_000.0))
    }

    fun parseInstant(raw: String?): Instant? {
        if (raw.isNullOrBlank()) return null
        return try {
            Instant.parse(raw.trim())
        } catch (_: DateTimeParseException) {
            null
        }
    }
}
