package com.routefinder.fleetdriver.nav

/**
 * Soft per-session budget for non-critical external APIs (TomTom / OpenWeather / Overpass).
 * Mirrors iOS ``APIUsageLedger`` soft guards without shared disk state.
 */
object ApiUsageLedger {
    enum class Provider { TOMTOM_FLOW, OPEN_WEATHER, OVERPASS }

    private val counts = mutableMapOf<Provider, Int>()
    private val softCaps = mapOf(
        Provider.TOMTOM_FLOW to 24,
        Provider.OPEN_WEATHER to 12,
        Provider.OVERPASS to 8,
    )

    @Synchronized
    fun allowsNonCriticalRequest(provider: Provider): Boolean {
        val used = counts[provider] ?: 0
        val cap = softCaps[provider] ?: 10
        return used < cap
    }

    @Synchronized
    fun record(provider: Provider) {
        counts[provider] = (counts[provider] ?: 0) + 1
    }

    @Synchronized
    fun resetForTests() {
        counts.clear()
    }
}
