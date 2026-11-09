package com.routefinder.fleetdriver.compliance

import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Preferred rest-stop kind for advisory HOS insertion ranking. */
enum class HosRestCandidateKind {
    OVERNIGHT_SECURE_PARKING,
    LAYBY,
    HIGH_FLOW_DIESEL,
    OTHER,
}

/** Candidate rest POI projected onto the route (id / label / arc). */
data class HosRestCandidate(
    val id: String,
    val label: String,
    val kind: HosRestCandidateKind,
    val arcLengthAlongRouteMeters: Double,
)

/** Suggested rest insertion along a planned path. */
data class HosRestInsertion(
    val id: String = UUID.randomUUID().toString(),
    val afterSegmentIndex: Int,
    val arcLengthMeters: Double? = null,
    val poiId: String? = null,
    val restDurationSeconds: Double,
    val reason: String,
    val physicsPreferred: Boolean = false,
)

/** Forecast result for a planned path (planning aid — not a legal VU). */
data class HosRestInsertionResult(
    val remainingContinuousDriveSeconds: Double,
    val remainingDailyDriveSeconds: Double,
    val insertions: List<HosRestInsertion>,
    val summary: String,
) {
    companion object {
        const val LEGAL_DISCLAIMER =
            "The digital tachograph is the legal record. This clock is a planning aid only."
    }
}

/**
 * Pure helper that places advisory HOS rest stops along a planned path.
 * Mirrors iOS ``HosRestInserter``.
 */
object HosRestInserter {
    const val THERMAL_STRESS_THRESHOLD = 0.55
    const val GRADE_STRESS_THRESHOLD = 6.0
    const val DEFAULT_BREAK_SECONDS = 45.0 * 60.0

    /** Optional per-segment kinetic stress (thermal + grade). */
    data class SegmentKineticStress(
        val thermalStressScore: Double,
        val gradePercentage: Double,
    )

    /**
     * Computes rest insertions before remaining continuous (and optional daily) drive is exhausted.
     * Returns empty when the path fits remaining drive time.
     */
    fun insertions(
        remainingContinuousDriveSeconds: Double,
        remainingDailyDriveSeconds: Double? = null,
        pathDurationsSeconds: List<Double>,
        pathArcLengthsMeters: List<Double>? = null,
        upcomingCandidates: List<HosRestCandidate>,
        kineticStress: List<SegmentKineticStress>? = null,
        restDurationSeconds: Double = DEFAULT_BREAK_SECONDS,
    ): List<HosRestInsertion> {
        if (pathDurationsSeconds.isEmpty()) return emptyList()

        val continuousBudget = max(0.0, remainingContinuousDriveSeconds)
        val dailyBudget = max(0.0, remainingDailyDriveSeconds ?: Double.MAX_VALUE)
        val driveBudget = min(continuousBudget, dailyBudget)
        if (driveBudget <= 0.0) {
            return listOf(
                makeInsertion(
                    afterSegmentIndex = -1,
                    arcLengthMeters = 0.0,
                    poi = bestPoi(
                        from = upcomingCandidates,
                        beforeArcMeters = pathArcLengthsMeters?.lastOrNull() ?: 0.0,
                        preferUpstreamOf = null,
                    ),
                    restDurationSeconds = restDurationSeconds,
                    reason = "No remaining drive time — rest before continuing.",
                    physicsPreferred = false,
                ),
            )
        }

        var cumulative = 0.0
        var deadlineIndex: Int? = null
        for ((index, duration) in pathDurationsSeconds.withIndex()) {
            cumulative += max(0.0, duration)
            if (cumulative > driveBudget) {
                deadlineIndex = index
                break
            }
        }
        val deadline = deadlineIndex ?: return emptyList()

        val deadlineArc = arcLength(
            atSegmentEnd = deadline,
            durations = pathDurationsSeconds,
            arcs = pathArcLengthsMeters,
        )

        val stressIndex = firstHighStressIndex(kineticStress, deadline)
        val physicsPreferred = stressIndex != null
        val preferredArcCap = if (stressIndex != null) {
            arcLength(
                atSegmentEnd = max(stressIndex - 1, -1),
                durations = pathDurationsSeconds,
                arcs = pathArcLengthsMeters,
            )
        } else {
            deadlineArc
        }

        val poi = bestPoi(
            from = upcomingCandidates,
            beforeArcMeters = if (preferredArcCap > 0) preferredArcCap else deadlineArc,
            preferUpstreamOf = preferredArcCap,
        ) ?: bestPoi(
            from = upcomingCandidates,
            beforeArcMeters = deadlineArc,
            preferUpstreamOf = null,
        )

        val afterIndex = when {
            poi != null && pathArcLengthsMeters != null -> {
                val poiArc = poi.arcLengthAlongRouteMeters
                max(0, pathArcLengthsMeters.indexOfLast { it <= poiArc }.coerceAtLeast(0))
            }
            stressIndex != null && stressIndex > 0 -> stressIndex - 1
            else -> max(0, deadline - 1)
        }

        val limitLabel = if (dailyBudget < continuousBudget) {
            "daily driving limit"
        } else {
            "4.5 h continuous drive"
        }
        val physicsNote = if (physicsPreferred) " upstream of high grade/thermal stress" else ""
        val reason = "45 min break before $limitLabel$physicsNote"

        return listOf(
            makeInsertion(
                afterSegmentIndex = afterIndex,
                arcLengthMeters = poi?.arcLengthAlongRouteMeters
                    ?: arcLength(
                        atSegmentEnd = afterIndex,
                        durations = pathDurationsSeconds,
                        arcs = pathArcLengthsMeters,
                    ),
                poi = poi,
                restDurationSeconds = restDurationSeconds,
                reason = reason,
                physicsPreferred = physicsPreferred,
            ),
        )
    }

    /** Builds a driver-facing forecast result with summary + disclaimer. */
    fun forecast(
        remainingContinuousDriveSeconds: Double,
        remainingDailyDriveSeconds: Double,
        pathDurationsSeconds: List<Double>,
        pathArcLengthsMeters: List<Double>? = null,
        upcomingCandidates: List<HosRestCandidate>,
        kineticStress: List<SegmentKineticStress>? = null,
    ): HosRestInsertionResult {
        val inserts = insertions(
            remainingContinuousDriveSeconds = remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds = remainingDailyDriveSeconds,
            pathDurationsSeconds = pathDurationsSeconds,
            pathArcLengthsMeters = pathArcLengthsMeters,
            upcomingCandidates = upcomingCandidates,
            kineticStress = kineticStress,
        )
        val summary = when {
            inserts.isEmpty() ->
                "Path fits remaining continuous/daily drive. ${HosRestInsertionResult.LEGAL_DISCLAIMER}"
            else -> {
                val first = inserts.first()
                val poiNote = first.poiId?.let { " near stop $it" } ?: ""
                "${first.reason}$poiNote. ${HosRestInsertionResult.LEGAL_DISCLAIMER}"
            }
        }
        return HosRestInsertionResult(
            remainingContinuousDriveSeconds = remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds = remainingDailyDriveSeconds,
            insertions = inserts,
            summary = summary,
        )
    }

    private fun makeInsertion(
        afterSegmentIndex: Int,
        arcLengthMeters: Double?,
        poi: HosRestCandidate?,
        restDurationSeconds: Double,
        reason: String,
        physicsPreferred: Boolean,
    ): HosRestInsertion =
        HosRestInsertion(
            afterSegmentIndex = afterSegmentIndex,
            arcLengthMeters = arcLengthMeters,
            poiId = poi?.id,
            restDurationSeconds = restDurationSeconds,
            reason = reason,
            physicsPreferred = physicsPreferred,
        )

    private fun firstHighStressIndex(
        kineticStress: List<SegmentKineticStress>?,
        beforeOrAt: Int,
    ): Int? {
        if (kineticStress == null) return null
        val upper = min(beforeOrAt, kineticStress.lastIndex)
        if (upper < 0) return null
        for (index in 0..upper) {
            val sample = kineticStress[index]
            if (sample.thermalStressScore >= THERMAL_STRESS_THRESHOLD ||
                abs(sample.gradePercentage) >= GRADE_STRESS_THRESHOLD
            ) {
                return index
            }
        }
        return null
    }

    private fun arcLength(
        atSegmentEnd: Int,
        durations: List<Double>,
        arcs: List<Double>?,
    ): Double {
        if (atSegmentEnd < 0) return 0.0
        if (arcs != null && atSegmentEnd < arcs.size) return arcs[atSegmentEnd]
        return durations.take(atSegmentEnd + 1).sum()
    }

    private fun bestPoi(
        from: List<HosRestCandidate>,
        beforeArcMeters: Double,
        preferUpstreamOf: Double?,
    ): HosRestCandidate? {
        val eligible = from.filter { poi ->
            poi.kind != HosRestCandidateKind.OTHER &&
                poi.arcLengthAlongRouteMeters >= 0 &&
                poi.arcLengthAlongRouteMeters <= beforeArcMeters
        }
        if (eligible.isEmpty()) return null
        return eligible.sortedWith(
            compareBy<HosRestCandidate> { kindRank(it.kind) }
                .thenByDescending { it.arcLengthAlongRouteMeters },
        ).first()
    }

    private fun kindRank(kind: HosRestCandidateKind): Int = when (kind) {
        HosRestCandidateKind.OVERNIGHT_SECURE_PARKING -> 0
        HosRestCandidateKind.LAYBY -> 1
        HosRestCandidateKind.HIGH_FLOW_DIESEL -> 2
        HosRestCandidateKind.OTHER -> 3
    }
}
