package com.routefinder.fleetdriver.compliance

/**
 * UK fleet fuel card networks the driver can select for ahead-of-route matching.
 * Mirrors iOS ``FuelCardProvider`` / ``FuelCardMatcher``.
 */
enum class FuelCardProvider(val rawValue: String, val displayName: String) {
    NONE("none", "None"),
    KEYFUELS("keyfuels", "Keyfuels"),
    UK_FUELS("ukFuels", "UK Fuels"),
    ALL_STAR("allStar", "AllStar"),
    ESSO("esso", "Esso"),
    BP("bp", "BP"),
    OTHER("other", "Other"),
    ;

    companion object {
        fun fromRaw(raw: String?): FuelCardProvider =
            entries.firstOrNull { it.rawValue.equals(raw, ignoreCase = true) } ?: NONE
    }
}

/** Minimal truck fuel POI for card matching (Ph32 parity). */
data class TruckFuelPoi(
    val id: String,
    val label: String,
    val latitude: Double,
    val longitude: Double,
    /** Lowercased amenity tokens including optional `brand:…` tags. */
    val amenities: Set<String> = emptySet(),
    val kind: Kind = Kind.HIGH_FLOW_DIESEL,
) {
    enum class Kind { HIGH_FLOW_DIESEL, OTHER }
}

/** Matches truck fuel POIs to the driver's selected fuel card network via name/brand substrings. */
object FuelCardMatcher {
    /** Returns whether the POI likely accepts the selected fuel card. */
    fun accepts(provider: FuelCardProvider, poi: TruckFuelPoi): Boolean {
        if (provider == FuelCardProvider.NONE) return false
        if (poi.kind != TruckFuelPoi.Kind.HIGH_FLOW_DIESEL) return false
        val haystack = searchableText(poi)
        if (haystack.isEmpty()) return false
        return needles(provider).any { haystack.contains(it) }
    }

    /** Banner copy when at least one ahead POI matches the selected provider. */
    fun aheadBannerMessage(provider: FuelCardProvider, matchingCount: Int): String? {
        if (provider == FuelCardProvider.NONE || matchingCount <= 0) return null
        return if (matchingCount == 1) {
            "Accepts your ${provider.displayName} card ahead"
        } else {
            "$matchingCount stops ahead accept your ${provider.displayName} card"
        }
    }

    /** Substrings matched against POI label and amenity brand tags (lowercased). */
    fun needles(provider: FuelCardProvider): List<String> = when (provider) {
        FuelCardProvider.NONE -> emptyList()
        FuelCardProvider.KEYFUELS -> listOf("keyfuels", "key fuels")
        FuelCardProvider.UK_FUELS -> listOf("uk fuels", "ukfuels", "texaco fleet", "texaco")
        FuelCardProvider.ALL_STAR -> listOf("allstar", "all star", "allstar fuel")
        FuelCardProvider.ESSO -> listOf("esso")
        FuelCardProvider.BP -> listOf("bp", "bp connect", "bp pulse")
        FuelCardProvider.OTHER -> emptyList()
    }

    private fun searchableText(poi: TruckFuelPoi): String {
        val parts = mutableListOf(poi.label.lowercase())
        for (amenity in poi.amenities) {
            if (amenity.startsWith("brand:")) {
                parts += amenity.removePrefix("brand:")
            } else {
                parts += amenity.lowercase()
            }
        }
        return parts.joinToString(" ")
    }
}
