package com.routefinder.fleetdriver.routing

/**
 * Matches authored UK toll advisories against a route polyline.
 * Mirrors iOS ``TollAdvisoryAlongRouteMatcher``.
 */
object TollAdvisoryAlongRouteMatcher {
    /**
     * Catalog advisories whose approach radius intersects any route vertex,
     * ordered by first hit along the polyline.
     */
    fun advisories(
        along: List<LatLon>,
        catalog: List<UKTollAdvisory> = UKTollAdvisoryCatalog.all,
    ): List<UKTollAdvisory> {
        if (along.size < 2 || catalog.isEmpty()) return emptyList()
        val hits = mutableListOf<Pair<Int, UKTollAdvisory>>()
        val seen = mutableSetOf<String>()
        for (advisory in catalog) {
            val tollPoint = advisory.coordinate
            var firstIndex: Int? = null
            for ((index, vertex) in along.withIndex()) {
                val distance = OrsResponseParser.haversineMeters(vertex, tollPoint)
                if (distance <= advisory.approachRadiusMeters) {
                    firstIndex = index
                    break
                }
            }
            if (firstIndex != null && seen.add(advisory.id)) {
                hits += firstIndex to advisory
            }
        }
        return hits.sortedBy { it.first }.map { it.second }
    }

    /**
     * Next advisory ahead of the driver along the route within [horizonMeters].
     */
    fun nextAdvisory(
        along: List<LatLon>,
        near: LatLon,
        horizonMeters: Double = 5_000.0,
        catalog: List<UKTollAdvisory> = UKTollAdvisoryCatalog.all,
    ): Pair<UKTollAdvisory, Double>? {
        val matched = advisories(along, catalog)
        if (matched.isEmpty()) return null
        var best: Pair<UKTollAdvisory, Double>? = null
        for (advisory in matched) {
            val distance = OrsResponseParser.haversineMeters(near, advisory.coordinate)
            if (distance > horizonMeters) continue
            val current = best
            if (current == null || distance < current.second) {
                best = advisory to distance
            }
        }
        return best
    }
}
