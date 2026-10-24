package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * UK LEZ / CAZ advisory catalog (simplified envelopes for Android C2).
 * Mirrors iOS ``UKLowEmissionZoneCatalog`` at announcement fidelity — not legal cadastre.
 * All 11 zones carry hand-authored rings when available (still not legal boundaries).
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
        /** Closed GeoJSON-style `[lon, lat]` ring; null falls back to circle. */
        val boundaryRing: List<DoubleArray>? = null,
    ) {
        fun contains(point: LatLon): Boolean {
            val ring = boundaryRing
            if (ring != null) return pointInPolygon(point, ring)
            return haversineMeters(point, center) <= radiusMeters
        }
    }

    val zones: List<Zone> = listOf(
        Zone("london-ulez", "London ULEZ", LatLon(51.5074, -0.1278), 18_000.0, EmissionClass.EURO6, UkLezBoundaries.londonULEZ),
        Zone("birmingham-caz", "Birmingham CAZ", LatLon(52.4862, -1.8904), 4_000.0, EmissionClass.EURO6, UkLezBoundaries.birminghamCAZ),
        Zone("bristol-caz", "Bristol CAZ", LatLon(51.4545, -2.5879), 3_500.0, EmissionClass.EURO6, UkLezBoundaries.bristolCAZ),
        Zone("sheffield-caz", "Sheffield CAZ", LatLon(53.3811, -1.4701), 3_500.0, EmissionClass.EURO6, UkLezBoundaries.sheffieldCAZ),
        Zone("bath-caz", "Bath CAZ", LatLon(51.3811, -2.3590), 2_500.0, EmissionClass.EURO6, UkLezBoundaries.bathCAZ),
        Zone("newcastle-caz", "Newcastle CAZ", LatLon(54.9783, -1.6178), 3_000.0, EmissionClass.EURO6, UkLezBoundaries.newcastleCAZ),
        Zone("manchester-caz", "Manchester CAZ", LatLon(53.4808, -2.2426), 3_500.0, EmissionClass.EURO6, UkLezBoundaries.manchesterCAZ),
        Zone("glasgow-lez", "Glasgow LEZ", LatLon(55.8642, -4.2518), 4_000.0, EmissionClass.EURO6, UkLezBoundaries.glasgowLEZ),
        Zone("bradford-caz", "Bradford CAZ", LatLon(53.7959, -1.7594), 3_000.0, EmissionClass.EURO6, UkLezBoundaries.bradfordCAZ),
        Zone("oxford-zez", "Oxford ZEZ", LatLon(51.7520, -1.2577), 2_500.0, EmissionClass.EURO6, UkLezBoundaries.oxfordZEZ),
        Zone("portsmouth-caz", "Portsmouth CAZ", LatLon(50.8198, -1.0880), 3_000.0, EmissionClass.EURO6, UkLezBoundaries.portsmouthCAZ),
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
            shouldAvoid(zone, emissionClass) && route.any { point -> zone.contains(point) }
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

    private fun pointInPolygon(point: LatLon, ring: List<DoubleArray>): Boolean {
        val vertexCount =
            if (ring.size >= 2 &&
                ring.first()[0] == ring.last()[0] &&
                ring.first()[1] == ring.last()[1]
            ) {
                ring.size - 1
            } else {
                ring.size
            }
        if (vertexCount < 3) return false
        var inside = false
        var j = vertexCount - 1
        for (i in 0 until vertexCount) {
            val xi = ring[i][0]
            val yi = ring[i][1]
            val xj = ring[j][0]
            val yj = ring[j][1]
            val intersect =
                ((yi > point.latitude) != (yj > point.latitude)) &&
                    (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-15) + xi)
            if (intersect) inside = !inside
            j = i
        }
        return inside
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
