package com.routefinder.fleetdriver.compliance

import android.net.Uri
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * Builds HTTPS deep links to parking partner sites (redirect only — no in-app commerce).
 * Mirrors iOS ``ParkingPartnerLinks``.
 */
object ParkingPartnerLinks {
    /**
     * TRAVIS truck parking map / search with optional focus coordinate.
     * Booking and fees stay between the driver and the parking operator.
     */
    fun travisUrl(
        latitude: Double,
        longitude: Double,
        label: String? = null,
    ): Uri = Uri.parse(travisUrlString(latitude, longitude, label))

    /** SNAP UK truck parking locator with search focus. */
    fun snapUrl(
        latitude: Double,
        longitude: Double,
        label: String? = null,
    ): Uri = Uri.parse(snapUrlString(latitude, longitude, label))

    /** String form for unit tests (same query shape as iOS). */
    fun travisUrlString(
        latitude: Double,
        longitude: Double,
        label: String? = null,
    ): String {
        val base = "https://www.yourtravis.com/map?lat=${formatCoord(latitude)}&lng=${formatCoord(longitude)}"
        val trimmed = label?.trim().orEmpty()
        return if (trimmed.isEmpty()) {
            base
        } else {
            "$base&q=${encode(trimmed)}"
        }
    }

    /** String form for unit tests (same query shape as iOS). */
    fun snapUrlString(
        latitude: Double,
        longitude: Double,
        label: String? = null,
    ): String {
        val base = "https://www.snapacc.com/find-parking?lat=${formatCoord(latitude)}&lon=${formatCoord(longitude)}"
        val trimmed = label?.trim().orEmpty()
        return if (trimmed.isEmpty()) {
            base
        } else {
            "$base&search=${encode(trimmed)}"
        }
    }

    private fun formatCoord(value: Double): String = String.format("%.5f", value)

    private fun encode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20")
}
