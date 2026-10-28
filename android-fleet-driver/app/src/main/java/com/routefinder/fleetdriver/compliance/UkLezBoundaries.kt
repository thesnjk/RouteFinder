package com.routefinder.fleetdriver.compliance

/**
 * Hand-authored simplified UK LEZ / CAZ boundary rings for ORS `avoid_polygons`.
 * Mirrors iOS ``UKLowEmissionZoneBoundaries`` — closed GeoJSON-style `[lon, lat]` envelopes,
 * not legal cadastral boundaries.
 */
object UkLezBoundaries {
    val londonULEZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-0.50, 51.48),
            doubleArrayOf(-0.42, 51.58),
            doubleArrayOf(-0.25, 51.65),
            doubleArrayOf(-0.05, 51.67),
            doubleArrayOf(0.12, 51.62),
            doubleArrayOf(0.22, 51.52),
            doubleArrayOf(0.18, 51.42),
            doubleArrayOf(0.05, 51.35),
            doubleArrayOf(-0.15, 51.32),
            doubleArrayOf(-0.35, 51.35),
            doubleArrayOf(-0.48, 51.42),
        ),
    )

    val birminghamCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.93, 52.470),
            doubleArrayOf(-1.88, 52.470),
            doubleArrayOf(-1.86, 52.482),
            doubleArrayOf(-1.86, 52.498),
            doubleArrayOf(-1.88, 52.505),
            doubleArrayOf(-1.93, 52.505),
            doubleArrayOf(-1.95, 52.492),
            doubleArrayOf(-1.95, 52.478),
        ),
    )

    val bristolCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-2.62, 51.440),
            doubleArrayOf(-2.56, 51.440),
            doubleArrayOf(-2.54, 51.452),
            doubleArrayOf(-2.54, 51.468),
            doubleArrayOf(-2.56, 51.475),
            doubleArrayOf(-2.62, 51.475),
            doubleArrayOf(-2.64, 51.462),
            doubleArrayOf(-2.64, 51.448),
        ),
    )

    val sheffieldCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.51, 53.365),
            doubleArrayOf(-1.44, 53.365),
            doubleArrayOf(-1.42, 53.378),
            doubleArrayOf(-1.42, 53.395),
            doubleArrayOf(-1.44, 53.402),
            doubleArrayOf(-1.51, 53.402),
            doubleArrayOf(-1.53, 53.390),
            doubleArrayOf(-1.53, 53.372),
        ),
    )

    val bathCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-2.385, 51.372),
            doubleArrayOf(-2.340, 51.372),
            doubleArrayOf(-2.330, 51.380),
            doubleArrayOf(-2.330, 51.392),
            doubleArrayOf(-2.340, 51.398),
            doubleArrayOf(-2.385, 51.398),
            doubleArrayOf(-2.395, 51.390),
            doubleArrayOf(-2.395, 51.378),
        ),
    )

    val newcastleCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.650, 54.965),
            doubleArrayOf(-1.590, 54.965),
            doubleArrayOf(-1.575, 54.975),
            doubleArrayOf(-1.575, 54.990),
            doubleArrayOf(-1.590, 54.998),
            doubleArrayOf(-1.650, 54.998),
            doubleArrayOf(-1.665, 54.988),
            doubleArrayOf(-1.665, 54.972),
        ),
    )

    val manchesterCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-2.300, 53.460),
            doubleArrayOf(-2.200, 53.460),
            doubleArrayOf(-2.180, 53.470),
            doubleArrayOf(-2.180, 53.495),
            doubleArrayOf(-2.200, 53.505),
            doubleArrayOf(-2.300, 53.505),
            doubleArrayOf(-2.320, 53.492),
            doubleArrayOf(-2.320, 53.472),
        ),
    )

    val glasgowLEZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-4.300, 55.845),
            doubleArrayOf(-4.200, 55.845),
            doubleArrayOf(-4.180, 55.855),
            doubleArrayOf(-4.180, 55.878),
            doubleArrayOf(-4.200, 55.888),
            doubleArrayOf(-4.300, 55.888),
            doubleArrayOf(-4.320, 55.875),
            doubleArrayOf(-4.320, 55.855),
        ),
    )

    val bradfordCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.800, 53.780),
            doubleArrayOf(-1.720, 53.780),
            doubleArrayOf(-1.700, 53.790),
            doubleArrayOf(-1.700, 53.812),
            doubleArrayOf(-1.720, 53.822),
            doubleArrayOf(-1.800, 53.822),
            doubleArrayOf(-1.820, 53.810),
            doubleArrayOf(-1.820, 53.790),
        ),
    )

    val oxfordZEZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.280, 51.740),
            doubleArrayOf(-1.235, 51.740),
            doubleArrayOf(-1.225, 51.748),
            doubleArrayOf(-1.225, 51.760),
            doubleArrayOf(-1.235, 51.768),
            doubleArrayOf(-1.280, 51.768),
            doubleArrayOf(-1.290, 51.760),
            doubleArrayOf(-1.290, 51.748),
        ),
    )

    val portsmouthCAZ: List<DoubleArray> = closed(
        listOf(
            doubleArrayOf(-1.120, 50.800),
            doubleArrayOf(-1.050, 50.800),
            doubleArrayOf(-1.040, 50.810),
            doubleArrayOf(-1.040, 50.832),
            doubleArrayOf(-1.050, 50.842),
            doubleArrayOf(-1.120, 50.842),
            doubleArrayOf(-1.130, 50.830),
            doubleArrayOf(-1.130, 50.810),
        ),
    )

    /** Closed rings keyed by catalog zone id (after ring vals so init order is valid). */
    val ringsByZoneId: Map<String, List<DoubleArray>> = mapOf(
        "london-ulez" to londonULEZ,
        "birmingham-caz" to birminghamCAZ,
        "bristol-caz" to bristolCAZ,
        "sheffield-caz" to sheffieldCAZ,
        "bath-caz" to bathCAZ,
        "newcastle-caz" to newcastleCAZ,
        "manchester-caz" to manchesterCAZ,
        "glasgow-lez" to glasgowLEZ,
        "bradford-caz" to bradfordCAZ,
        "oxford-zez" to oxfordZEZ,
        "portsmouth-caz" to portsmouthCAZ,
    )

    private fun closed(points: List<DoubleArray>): List<DoubleArray> {
        if (points.isEmpty()) return points
        val first = points.first()
        val last = points.last()
        if (first[0] == last[0] && first[1] == last[1]) return points
        return points + listOf(doubleArrayOf(first[0], first[1]))
    }
}
