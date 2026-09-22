package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * UK LEZ / CAZ advisory catalog (simplified envelopes for Android C2).
 * Mirrors iOS ``UKLowEmissionZoneCatalog`` at announcement fidelity — not legal cadastre.
 */
object UkLezCatalog {
    enum class EmissionClass(val euroRank: Int) {
        EURO3(3), EURO4(4), EURO5(5), EURO6(6),
    }

    data class Zone(
        val id: String,
        val name: String,
        val center: LatLon,
        val radiusMeters: Double,
        val minimumCompliantClass: EmissionClass,
    )

    val zones: List<Zone> = listOf(
        Zone("london-ulez", "London ULEZ", LatLon(51.5074, -0.1278), 12_000.0, EmissionClass.EURO6),
        Zone("birmingham-caz", "Birmingham CAZ", LatLon(52.4862, -1.8904), 4_000.0, EmissionClass.EURO6),
        Zone("bristol-caz", "Bristol CAZ", LatLon(51.4545, -2.5879), 3_500.0, EmissionClass.EURO6),
        Zone("sheffield-caz", "Sheffield CAZ", LatLon(53.3811, -1.4701), 3_500.0, EmissionClass.EURO6),
        Zone("bath-caz", "Bath CAZ", LatLon(51.3811, -2.3590), 2_500.0, EmissionClass.EURO6),
        Zone("newcastle-caz", "Newcastle CAZ", LatLon(54.9783, -1.6178), 3_000.0, EmissionClass.EURO6),
    )

    fun shouldAvoid(zone: Zone, emissionClass: EmissionClass?): Boolean {
        val rank = emissionClass?.euroRank ?: 0
        return rank < zone.minimumCompliantClass.euroRank
    }

    /** Zones that intersect the route polyline and should be avoided for [emissionClass]. */
    fun intersectingAvoidZones(
        route: List<LatLon>,
        emissionClass: EmissionClass?,
        avoidEnabled: Boolean,
    ): List<Zone> {
        if (!avoidEnabled || route.isEmpty()) return emptyList()
        return zones.filter { zone ->
            shouldAvoid(zone, emissionClass) && route.any { point ->
                haversineMeters(point, zone.center) <= zone.radiusMeters
            }
        }
    }

    fun announcement(
        route: List<LatLon>,
        emissionClass: EmissionClass?,
        avoidEnabled: Boolean,
    ): String? {
        val hits = intersectingAvoidZones(route, emissionClass, avoidEnabled)
        if (hits.isEmpty()) return null
        val names = hits.joinToString(", ") { it.name }
        return if (avoidEnabled) {
            "LEZ/CAZ: avoiding $names (check Euro class)"
        } else {
            "LEZ/CAZ ahead: $names — verify charge / compliance"
        }
    }

    private fun haversineMeters(a: LatLon, b: LatLon): Double {
        val earth = 6_371_000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * atan2(sqrt(h), sqrt(maxOf(0.0, 1 - h)))
    }
}
