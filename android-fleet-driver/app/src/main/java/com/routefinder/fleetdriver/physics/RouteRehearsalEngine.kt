package com.routefinder.fleetdriver.physics

import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** HGV physics defaults for incremental rehearsal (Wave 2). */
object VehiclePhysicsDefaults {
    const val MASS_KG = 40_000.0
    const val POWER_KW = 330.0
    const val WHEELBASE_M = 6.5
    const val CRUISE_MPS = 22.0 // ~80 km/h
    const val MIN_MPS = 4.0
    const val MAX_MPS = 25.0 // ~90 km/h legal HGV
}

/**
 * Simplified grade-aware headless rehearsal along a polyline with optional elevation.
 * Returns kinetic ETA seconds (faster than ORS when flat; slower on climbs).
 */
object RouteRehearsalEngine {
    fun rehearse(
        coordinates: List<LatLon>,
        webEtaSeconds: Double,
    ): Double {
        if (coordinates.size < 2) return webEtaSeconds
        var time = 0.0
        for (i in 0 until coordinates.size - 1) {
            val a = coordinates[i]
            val b = coordinates[i + 1]
            val dist = OrsResponseParser.haversineMeters(a, b)
            if (dist < 0.5) continue
            val elevA = a.elevationMeters
            val elevB = b.elevationMeters
            val grade = if (elevA != null && elevB != null && dist > 1.0) {
                (elevB - elevA) / dist
            } else {
                0.0
            }
            val speed = gradeSpeedMps(grade)
            time += dist / speed
        }
        // Blend toward web ETA so extreme grades don't invent absurd times.
        val kinetic = time
        return if (webEtaSeconds > 0) {
            min(webEtaSeconds * 3.0, max(webEtaSeconds * 0.5, kinetic))
        } else {
            kinetic
        }
    }

    fun gradeSpeedMps(grade: Double): Double {
        val g = grade.coerceIn(-0.15, 0.15)
        // Climb slows; downhill slightly faster but capped.
        val factor = when {
            g > 0.02 -> 1.0 - min(0.55, g * 8.0)
            g < -0.02 -> 1.0 + min(0.15, abs(g) * 3.0)
            else -> 1.0
        }
        return (VehiclePhysicsDefaults.CRUISE_MPS * factor)
            .coerceIn(VehiclePhysicsDefaults.MIN_MPS, VehiclePhysicsDefaults.MAX_MPS)
    }
}
