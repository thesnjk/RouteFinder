package com.routefinder.fleetdriver.routing

/**
 * Maps fleet ORS / Pelias proxy HTTP failures to driver-facing copy.
 * Parity with iOS [RouteFailureMapper] 429 cap messaging — no Android framework deps.
 */
object FleetProxyErrorMapper {
    const val ORS_ROUTE_CAP_MESSAGE =
        "Fleet ORS daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow."

    const val GEOCODE_CAP_MESSAGE =
        "Fleet geocode daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow."

    private const val BODY_SNIPPET_MAX = 200

    enum class Kind {
        ORS_ROUTE,
        GEOCODE,
    }

    /**
     * @param statusCode HTTP status from the fleet proxy
     * @param body response body (may include Hummingbird "daily cap" text)
     * @param kind which proxy surface failed
     */
    fun userMessage(statusCode: Int, body: String, kind: Kind = Kind.ORS_ROUTE): String {
        val snippet = body.trim().replace("\n", " ").take(BODY_SNIPPET_MAX)
        val lower = snippet.lowercase()
        val looksLikeCap =
            statusCode == 429 ||
                lower.contains("daily cap") ||
                lower.contains("too many requests")

        if (looksLikeCap) {
            return when {
                kind == Kind.GEOCODE || lower.contains("geocode") -> GEOCODE_CAP_MESSAGE
                else -> ORS_ROUTE_CAP_MESSAGE
            }
        }

        val prefix = when (kind) {
            Kind.ORS_ROUTE -> "ORS route"
            Kind.GEOCODE -> "geocode"
        }

        if (statusCode == 401 || statusCode == 403) {
            return if (snippet.isNotEmpty()) {
                "$prefix $statusCode: $snippet"
            } else {
                "$prefix $statusCode: Fleet API key rejected. Check the shared key with the operator."
            }
        }

        return if (snippet.isNotEmpty()) {
            "$prefix $statusCode: $snippet"
        } else {
            "$prefix $statusCode"
        }
    }
}
