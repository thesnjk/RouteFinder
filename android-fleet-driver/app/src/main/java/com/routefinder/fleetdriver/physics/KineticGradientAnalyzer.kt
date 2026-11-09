package com.routefinder.fleetdriver.physics

import com.routefinder.fleetdriver.compliance.HosRestInserter
import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import kotlin.math.abs
import kotlin.math.min

/**
 * Per-segment grade / thermal stress from ORS elevation polylines.
 * Mirrors iOS ``KineticGradientAnalyzer.analyzeTopology`` for HOS rest bias.
 */
object KineticGradientAnalyzer {
    /** Neutral sample when a segment is too short or lacks elevation. */
    val NEUTRAL = HosRestInserter.SegmentKineticStress(
        thermalStressScore = 0.0,
        gradePercentage = 0.0,
    )

    /**
     * Analyzes route topology and returns one stress sample per consecutive pair
     * (aligned with path duration segments used by ``HosRestInserter``).
     *
     * Grade is percent (rise/run × 100). Downhill steep grades raise thermal stress;
     * climbs are tracked via positive [HosRestInserter.SegmentKineticStress.gradePercentage].
     */
    fun analyzeTopology(
        path: List<LatLon>,
        weightTons: Double,
    ): List<HosRestInserter.SegmentKineticStress> {
        if (path.size < 2) return emptyList()
        val massKg = weightTons * 1_000.0
        val out = ArrayList<HosRestInserter.SegmentKineticStress>(path.size - 1)
        for (i in 0 until path.lastIndex) {
            val current = path[i]
            val next = path[i + 1]
            val distance = OrsResponseParser.haversineMeters(current, next)
            if (distance <= 0.5) {
                out += NEUTRAL
                continue
            }
            val elevA = current.elevationMeters ?: 0.0
            val elevB = next.elevationMeters ?: 0.0
            val gradePercent = ((elevB - elevA) / distance) * 100.0
            var thermal = 0.0
            if (gradePercent < -2.0) {
                thermal = min(1.0, (massKg / 44_000.0) * (abs(gradePercent) / 15.0))
            }
            out += HosRestInserter.SegmentKineticStress(
                thermalStressScore = thermal,
                gradePercentage = gradePercent,
            )
        }
        return out
    }

    /**
     * Aligns [stress] to [targetLength] by truncating or padding with [NEUTRAL]
     * so it matches path duration segment count.
     */
    fun alignToSegmentCount(
        stress: List<HosRestInserter.SegmentKineticStress>,
        targetLength: Int,
    ): List<HosRestInserter.SegmentKineticStress> {
        if (targetLength <= 0) return emptyList()
        if (stress.size == targetLength) return stress
        if (stress.size > targetLength) return stress.take(targetLength)
        return stress + List(targetLength - stress.size) { NEUTRAL }
    }
}
