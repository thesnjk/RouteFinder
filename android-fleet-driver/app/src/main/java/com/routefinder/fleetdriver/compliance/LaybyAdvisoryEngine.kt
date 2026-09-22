package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Lightweight layby / break-site advisory along the route corridor (Android C2).
 * Uses a small built-in UK trunk-road rest stop list — not live occupancy.
 */
object LaybyAdvisoryEngine {
    data class Site(val name: String, val coordinate: LatLon)

    private val sites = listOf(
        Site("M1 J18 Watford Gap", LatLon(52.306, -1.122)),
        Site("M6 J15 Keele", LatLon(53.003, -2.288)),
        Site("M5 J9 Strensham", LatLon(52.037, -2.122)),
        Site("A14 Newmarket", LatLon(52.246, 0.404)),
        Site("A1(M) Baldock", LatLon(51.998, -0.188)),
    )

    fun nearestAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double = 0.0,
        maxAheadMeters: Double = 40_000.0,
    ): String? {
        if (route.size < 2) return null
        val cumulative = cumulative(route)
        val total = cumulative.lastOrNull() ?: return null
        var best: Pair<String, Double>? = null
        for (site in sites) {
            val proj = project(site.coordinate, route, cumulative) ?: continue
            if (proj.second > 2_500) continue
            val remaining = proj.first - currentArcLengthMeters
            if (remaining <= 0 || remaining > maxAheadMeters || proj.first > total) continue
            if (best == null || remaining < best.second) {
                best = site.name to remaining
            }
        }
        val hit = best ?: return null
        val km = (hit.second / 1_000).toInt().coerceAtLeast(1)
        return "Layby ahead: ${hit.first} (~${km} km)"
    }

    private fun cumulative(route: List<LatLon>): List<Double> {
        val out = mutableListOf(0.0)
        var sum = 0.0
        for (i in 0 until route.lastIndex) {
            sum += haversine(route[i], route[i + 1])
            out += sum
        }
        return out
    }

    private fun project(
        point: LatLon,
        route: List<LatLon>,
        cumulative: List<Double>,
    ): Pair<Double, Double>? {
        var bestCross = Double.MAX_VALUE
        var bestArc = 0.0
        for (i in 0 until route.lastIndex) {
            val a = route[i]
            val b = route[i + 1]
            val dx = b.longitude - a.longitude
            val dy = b.latitude - a.latitude
            val len2 = dx * dx + dy * dy
            val t = if (len2 <= 0) 0.0 else {
                ((point.longitude - a.longitude) * dx + (point.latitude - a.latitude) * dy) / len2
            }.coerceIn(0.0, 1.0)
            val proj = LatLon(a.latitude + t * dy, a.longitude + t * dx)
            val cross = haversine(point, proj)
            val arc = cumulative[i] + t * (cumulative[i + 1] - cumulative[i])
            if (cross < bestCross) {
                bestCross = cross
                bestArc = arc
            }
        }
        return bestArc to bestCross
    }

    private fun haversine(a: LatLon, b: LatLon): Double {
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
