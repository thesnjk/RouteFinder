package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import java.util.Calendar
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Lightweight layby / break-site advisory along the route corridor (Android C2).
 * Availability tiers fuse hour-of-day priors + on-device crowd taps (not live bay sensors).
 */
object LaybyAdvisoryEngine {
    data class Site(
        val id: String,
        val name: String,
        val coordinate: LatLon,
    )

    /** Structured layby ahead advisory with parking availability tier. */
    data class Advisory(
        val site: Site,
        val remainingMeters: Double,
        val message: String,
        val tier: ParkingAvailabilityTier,
        val occupancyPrior: LaybyOccupancyPrior,
    )

    /** Seed UK corridor sites used when Overpass catalog is empty / offline. */
    val seedSites: List<Site> = listOf(
        Site("m1-watford-gap", "M1 J18 Watford Gap", LatLon(52.306, -1.122)),
        Site("m6-keele", "M6 J15 Keele", LatLon(53.003, -2.288)),
        Site("m5-strensham", "M5 J9 Strensham", LatLon(52.037, -2.122)),
        Site("a14-newmarket", "A14 Newmarket", LatLon(52.246, 0.404)),
        Site("a1m-baldock", "A1(M) Baldock", LatLon(51.998, -0.188)),
    )

    fun nearestAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double = 0.0,
        maxAheadMeters: Double = 40_000.0,
        skipCount: Int = 0,
        occupancyStore: LaybyOccupancyStore? = null,
        hourOfDay: Int = Calendar.getInstance().get(Calendar.HOUR_OF_DAY),
        sites: List<Site> = seedSites,
    ): Advisory? {
        val ranked = rankedAhead(
            route = route,
            currentArcLengthMeters = currentArcLengthMeters,
            maxAheadMeters = maxAheadMeters,
            occupancyStore = occupancyStore,
            hourOfDay = hourOfDay,
            sites = sites,
        )
        return ranked.getOrNull(skipCount.coerceAtLeast(0))
    }

    /**
     * Advisories sorted nearest-first along the route.
     * Used by voice “next layby” to skip the current candidate.
     * Pass Overpass [sites] when available; falls back to [seedSites].
     */
    fun rankedAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double = 0.0,
        maxAheadMeters: Double = 40_000.0,
        occupancyStore: LaybyOccupancyStore? = null,
        hourOfDay: Int = Calendar.getInstance().get(Calendar.HOUR_OF_DAY),
        sites: List<Site> = seedSites,
    ): List<Advisory> {
        if (route.size < 2) return emptyList()
        val catalog = sites.ifEmpty { seedSites }
        val cumulative = cumulative(route)
        val total = cumulative.lastOrNull() ?: return emptyList()
        val hits = mutableListOf<Pair<Site, Double>>()
        for (site in catalog) {
            val proj = project(site.coordinate, route, cumulative) ?: continue
            if (proj.second > 2_500) continue
            val remaining = proj.first - currentArcLengthMeters
            if (remaining <= 0 || remaining > maxAheadMeters || proj.first > total) continue
            hits += site to remaining
        }
        val prior = LaybyOccupancyPrior.forHour(hourOfDay)
        return hits
            .sortedBy { it.second }
            .map { (site, remaining) ->
                val tier = occupancyStore?.resolveTier(site.id, hourOfDay)
                    ?: ParkingAvailabilityTier.fromOccupancyPrior(prior)
                val km = (remaining / 1_000).toInt().coerceAtLeast(1)
                Advisory(
                    site = site,
                    remainingMeters = remaining,
                    message = "Layby ahead: ${site.name} (~${km} km)",
                    tier = tier,
                    occupancyPrior = prior,
                )
            }
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
