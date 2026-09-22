package com.routefinder.fleetdriver.compliance

import com.routefinder.fleetdriver.routing.LatLon
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Builds ORS `avoid_polygons` rings for UK LEZ / CAZ zones the vehicle is not compliant with.
 * Mirrors iOS ``LEZAvoidPolicy`` (area + long-haul caps; destination-inside zones omitted).
 */
object LezAvoidPolicy {
    /** Soft cap under HeiGIT ORS ~200 km² hard limit. */
    const val AVOID_POLYGON_AREA_CAP_SQUARE_METERS: Double = 2.0e8 * 0.9

    /** Soft haversine cap: omit all LEZ avoids on longer hauls (ORS 2004). */
    const val AVOID_POLYGONS_MAX_HAVERSINE_METERS: Double = 140_000.0

    /**
     * Closed GeoJSON-style `[lon, lat]` rings for zones to avoid on the next ORS request.
     *
     * Missing [emissionClass] is treated as non-compliant (avoid when toggle is on).
     * Zones containing [destination] are omitted so routing can still reach the stop.
     * Oversized rings (e.g. London ULEZ circle) are omitted — announcements still apply.
     */
    fun polygons(
        emissionClass: UkLezCatalog.EmissionClass?,
        avoidEnabled: Boolean,
        origin: LatLon,
        destination: LatLon,
        zones: List<UkLezCatalog.Zone> = UkLezCatalog.zones,
    ): List<List<DoubleArray>> {
        if (!avoidEnabled) return emptyList()
        if (haversineMeters(origin, destination) > AVOID_POLYGONS_MAX_HAVERSINE_METERS) {
            return emptyList()
        }
        val rings = mutableListOf<List<DoubleArray>>()
        for (zone in zones) {
            if (!shouldAvoid(zone, emissionClass)) continue
            if (zoneContains(zone, destination)) continue
            val ring = avoidPolygonRing(zone)
            if (approximateRingAreaSquareMeters(ring) > AVOID_POLYGON_AREA_CAP_SQUARE_METERS) {
                continue
            }
            rings += ring
        }
        return rings
    }

    fun shouldAvoid(zone: UkLezCatalog.Zone, emissionClass: UkLezCatalog.EmissionClass?): Boolean {
        val rank = emissionClass?.euroRank ?: 0
        return rank < zone.minimumCompliantClass.euroRank
    }

    /** N-gon circle approximation around [zone] center (closed ring of `[lon, lat]`). */
    fun avoidPolygonRing(zone: UkLezCatalog.Zone, pointCount: Int = 16): List<DoubleArray> {
        val count = maxOf(3, pointCount)
        val earthRadius = 6_371_000.0
        val angularDistance = zone.radiusMeters / earthRadius
        val lat1 = Math.toRadians(zone.center.latitude)
        val lon1 = Math.toRadians(zone.center.longitude)
        val ring = ArrayList<DoubleArray>(count + 1)
        for (index in 0 until count) {
            val bearing = 2.0 * Math.PI * index / count
            val lat2 = asin(
                sin(lat1) * cos(angularDistance) +
                    cos(lat1) * sin(angularDistance) * cos(bearing),
            )
            val lon2 = lon1 + atan2(
                sin(bearing) * sin(angularDistance) * cos(lat1),
                cos(angularDistance) - sin(lat1) * sin(lat2),
            )
            ring += doubleArrayOf(Math.toDegrees(lon2), Math.toDegrees(lat2))
        }
        ring += doubleArrayOf(ring.first()[0], ring.first()[1])
        return ring
    }

    fun approximateRingAreaSquareMeters(ring: List<DoubleArray>): Double {
        val vertexCount =
            if (ring.size >= 2 &&
                ring.first()[0] == ring.last()[0] &&
                ring.first()[1] == ring.last()[1]
            ) {
                ring.size - 1
            } else {
                ring.size
            }
        if (vertexCount < 3) return 0.0
        var latSum = 0.0
        for (i in 0 until vertexCount) latSum += ring[i][1]
        val meanLat = latSum / vertexCount
        val metersPerDegLat = 111_320.0
        val metersPerDegLon = 111_320.0 * cos(Math.toRadians(meanLat))
        var area = 0.0
        for (i in 0 until vertexCount) {
            val j = (i + 1) % vertexCount
            val xi = ring[i][0] * metersPerDegLon
            val yi = ring[i][1] * metersPerDegLat
            val xj = ring[j][0] * metersPerDegLon
            val yj = ring[j][1] * metersPerDegLat
            area += xi * yj - xj * yi
        }
        return kotlin.math.abs(area) / 2.0
    }

    private fun zoneContains(zone: UkLezCatalog.Zone, point: LatLon): Boolean =
        haversineMeters(zone.center, point) <= zone.radiusMeters

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
