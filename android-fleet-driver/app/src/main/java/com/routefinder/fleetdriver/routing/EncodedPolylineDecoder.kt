package com.routefinder.fleetdriver.routing

/**
 * Decodes Google-encoded polylines (polyline5 / polyline6).
 * Ports EncodedPolylineDecoder from iOS.
 */
object EncodedPolylineDecoder {
    fun decode(encoded: String, precision: Int = 5): List<LatLon> {
        if (encoded.isEmpty()) return emptyList()
        val factor = Math.pow(10.0, precision.toDouble())
        val coordinates = mutableListOf<LatLon>()
        var index = 0
        var latitude = 0
        var longitude = 0
        while (index < encoded.length) {
            val latDelta = decodeComponent(encoded, index) ?: break
            index = latDelta.second
            latitude += latDelta.first
            val lonDelta = decodeComponent(encoded, index) ?: break
            index = lonDelta.second
            longitude += lonDelta.first
            coordinates.add(
                LatLon(
                    latitude = latitude / factor,
                    longitude = longitude / factor,
                ),
            )
        }
        return coordinates
    }

    private fun decodeComponent(encoded: String, start: Int): Pair<Int, Int>? {
        var result = 0
        var shift = 0
        var index = start
        var byte: Int
        do {
            if (index >= encoded.length) return null
            byte = encoded[index].code - 63
            index++
            result = result or ((byte and 0x1F) shl shift)
            shift += 5
        } while (byte >= 0x20)
        val delta = if ((result and 1) != 0) (result shr 1).inv() else (result shr 1)
        return delta to index
    }
}

data class LatLon(
    val latitude: Double,
    val longitude: Double,
    val elevationMeters: Double? = null,
)
