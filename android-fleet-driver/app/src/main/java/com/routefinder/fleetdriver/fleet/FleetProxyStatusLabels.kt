package com.routefinder.fleetdriver.fleet

import org.json.JSONObject
import kotlin.math.max

/**
 * Connection-panel labels for GET /v1/proxy/status — parity with web
 * `fleetProxyStatusLabel.ts` and Swift `FleetProxyDeskStatus`.
 */
object FleetProxyStatusLabels {
    const val NEAR_CAP_FRACTION = 0.9

    private const val NEAR_CAP_WARNING =
        "Near daily proxy cap — raise --route-daily-cap / --geocode-daily-cap or wait until tomorrow."

    /** Masks a bearer/API token for display (never show full secret). */
    fun maskApiKey(token: String): String {
        val trimmed = token.trim()
        if (trimmed.isEmpty()) return "(none)"
        if (trimmed.length <= 8) return "••••"
        return "${trimmed.take(4)}…${trimmed.takeLast(4)}"
    }

    fun maskedTokenLine(token: String): String = "Token: ${maskApiKey(token)}"

    /** Authenticated depot line when orgName is present. */
    fun authenticatedDepotLine(status: JSONObject): String? {
        val name = status.optString("orgName", "").trim()
        if (name.isEmpty()) return null
        val id = status.optString("orgId", "").trim()
        return if (id.isNotEmpty()) {
            "Authenticated depot: $name ($id)"
        } else {
            "Authenticated depot: $name"
        }
    }

    fun routesRemaining(status: JSONObject): Int {
        val cap = status.optInt("routeDailyCap", 0)
        val used = status.optInt("routesToday", 0)
        return max(0, cap - used)
    }

    fun geocodesRemaining(status: JSONObject): Int {
        val cap = status.optInt("geocodeDailyCap", 0)
        val used = status.optInt("geocodeToday", 0)
        return max(0, cap - used)
    }

    fun orsSummaryLine(status: JSONObject): String {
        val configured = status.optBoolean("orsConfigured", false)
        if (!configured) {
            return "ORS proxy: off (start server with --ors-key for address search and driver routing)"
        }
        val routesToday = status.optInt("routesToday", 0)
        val routeCap = status.optInt("routeDailyCap", 0)
        val geocodeToday = status.optInt("geocodeToday", 0)
        val geocodeCap = status.optInt("geocodeDailyCap", 0)
        return "ORS proxy: on · $routesToday/$routeCap routes · ${routesRemaining(status)} left" +
            " · $geocodeToday/$geocodeCap geocodes · ${geocodesRemaining(status)} left"
    }

    fun nearCapWarning(status: JSONObject): String? {
        if (!status.optBoolean("orsConfigured", false)) return null
        val nearRoutes = isNearCap(status.optInt("routesToday", 0), status.optInt("routeDailyCap", 0))
        val nearGeocode = isNearCap(status.optInt("geocodeToday", 0), status.optInt("geocodeDailyCap", 0))
        return if (nearRoutes || nearGeocode) NEAR_CAP_WARNING else null
    }

    private fun isNearCap(used: Int, cap: Int): Boolean {
        if (cap <= 0) return false
        return used >= cap * NEAR_CAP_FRACTION
    }
}
