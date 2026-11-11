package com.routefinder.fleetdriver.compliance

/**
 * Hand-authored / open-data-simplified UK LEZ / CAZ boundary rings for ORS `avoid_polygons`.
 * Mirrors iOS ``UKLowEmissionZoneBoundaries`` — closed GeoJSON-style `[lon, lat]` envelopes,
 * not legal cadastral boundaries. Sheffield + Birmingham + Bradford densified from OGL /
 * OSM-published outlines (~28 verts, under ORS avoid area caps).
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
            doubleArrayOf(-1.92649, 52.47859),
            doubleArrayOf(-1.92557, 52.47701),
            doubleArrayOf(-1.9213, 52.47451),
            doubleArrayOf(-1.91805, 52.4734),
            doubleArrayOf(-1.91754, 52.47264),
            doubleArrayOf(-1.91337, 52.47181),
            doubleArrayOf(-1.90438, 52.46805),
            doubleArrayOf(-1.89746, 52.46693),
            doubleArrayOf(-1.89398, 52.4654),
            doubleArrayOf(-1.88773, 52.46362),
            doubleArrayOf(-1.88641, 52.4639),
            doubleArrayOf(-1.88196, 52.46721),
            doubleArrayOf(-1.87785, 52.46952),
            doubleArrayOf(-1.87548, 52.47233),
            doubleArrayOf(-1.87513, 52.47486),
            doubleArrayOf(-1.87653, 52.47931),
            doubleArrayOf(-1.87778, 52.48112),
            doubleArrayOf(-1.88034, 52.48318),
            doubleArrayOf(-1.88752, 52.49153),
            doubleArrayOf(-1.8899, 52.49228),
            doubleArrayOf(-1.89497, 52.49215),
            doubleArrayOf(-1.90841, 52.49388),
            doubleArrayOf(-1.91467, 52.49238),
            doubleArrayOf(-1.91628, 52.49039),
            doubleArrayOf(-1.91745, 52.48723),
            doubleArrayOf(-1.91912, 52.48464),
            doubleArrayOf(-1.92247, 52.4828),
            doubleArrayOf(-1.92599, 52.47974),
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
            doubleArrayOf(-1.44754, 53.38447),
            doubleArrayOf(-1.45413, 53.38541),
            doubleArrayOf(-1.45855, 53.38677),
            doubleArrayOf(-1.45821, 53.38766),
            doubleArrayOf(-1.46091, 53.38698),
            doubleArrayOf(-1.46105, 53.38827),
            doubleArrayOf(-1.46203, 53.38761),
            doubleArrayOf(-1.4636, 53.38908),
            doubleArrayOf(-1.46916, 53.38993),
            doubleArrayOf(-1.46833, 53.38915),
            doubleArrayOf(-1.4703, 53.38723),
            doubleArrayOf(-1.47456, 53.38753),
            doubleArrayOf(-1.47658, 53.38879),
            doubleArrayOf(-1.47987, 53.3874),
            doubleArrayOf(-1.48407, 53.38364),
            doubleArrayOf(-1.48341, 53.382),
            doubleArrayOf(-1.48433, 53.38169),
            doubleArrayOf(-1.48432, 53.37794),
            doubleArrayOf(-1.47981, 53.37432),
            doubleArrayOf(-1.47817, 53.37445),
            doubleArrayOf(-1.47877, 53.3737),
            doubleArrayOf(-1.47685, 53.37257),
            doubleArrayOf(-1.47315, 53.37365),
            doubleArrayOf(-1.46816, 53.3734),
            doubleArrayOf(-1.4627, 53.37454),
            doubleArrayOf(-1.46462, 53.37752),
            doubleArrayOf(-1.46052, 53.38216),
            doubleArrayOf(-1.45841, 53.38245),
            doubleArrayOf(-1.45871, 53.38385),
            doubleArrayOf(-1.45457, 53.38508),
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
            doubleArrayOf(-1.8025, 53.84146),
            doubleArrayOf(-1.81567, 53.84042),
            doubleArrayOf(-1.81161, 53.8382),
            doubleArrayOf(-1.8185, 53.83541),
            doubleArrayOf(-1.81094, 53.8331),
            doubleArrayOf(-1.81874, 53.8265),
            doubleArrayOf(-1.80796, 53.82477),
            doubleArrayOf(-1.79786, 53.82814),
            doubleArrayOf(-1.78129, 53.82545),
            doubleArrayOf(-1.78373, 53.82422),
            doubleArrayOf(-1.78271, 53.81953),
            doubleArrayOf(-1.77006, 53.8056),
            doubleArrayOf(-1.78519, 53.79932),
            doubleArrayOf(-1.78247, 53.79074),
            doubleArrayOf(-1.77491, 53.78661),
            doubleArrayOf(-1.78352, 53.78253),
            doubleArrayOf(-1.77863, 53.7772),
            doubleArrayOf(-1.74678, 53.76824),
            doubleArrayOf(-1.73174, 53.77081),
            doubleArrayOf(-1.72815, 53.77548),
            doubleArrayOf(-1.72524, 53.77385),
            doubleArrayOf(-1.72661, 53.7755),
            doubleArrayOf(-1.72173, 53.77905),
            doubleArrayOf(-1.71738, 53.79009),
            doubleArrayOf(-1.7256, 53.80541),
            doubleArrayOf(-1.73719, 53.81108),
            doubleArrayOf(-1.75647, 53.80949),
            doubleArrayOf(-1.77477, 53.82964),
            doubleArrayOf(-1.76983, 53.83419),
            doubleArrayOf(-1.77135, 53.83646),
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
