package com.routefinder.fleetdriver.compliance

/**
 * Partner used for a parking book redirect (TRAVIS / SNAP).
 */
enum class ParkingBookPartner {
    TRAVIS,
    SNAP,
    ;

    val displayName: String
        get() = when (this) {
            TRAVIS -> "TRAVIS"
            SNAP -> "SNAP"
        }
}

/**
 * Stashed when the driver opens a partner book link so nav can resume after the browser bounce.
 * Partners do not expose a documented return URL — app-side resume chrome only.
 */
data class PendingParkingBookReturn(
    val id: String,
    val label: String,
    val latitude: Double,
    val longitude: Double,
    val partner: ParkingBookPartner,
    val openedAtMs: Long = System.currentTimeMillis(),
    val tier: ParkingAvailabilityTier? = null,
) {
    fun isFresh(nowMs: Long = System.currentTimeMillis()): Boolean =
        nowMs - openedAtMs < FRESHNESS_LIMIT_MS

    val resumeMessage: String
        get() = "Back from ${partner.displayName} — continue to $label?"

    companion object {
        const val FRESHNESS_LIMIT_MS = 30L * 60L * 1_000L
    }
}

/** Pure helpers for tier-aware parking book CTA copy. */
object ParkingBookCtaCopy {
    fun caption(tier: ParkingAvailabilityTier?): String? =
        when (tier) {
            null -> null
            ParkingAvailabilityTier.AMPLE -> null
            ParkingAvailabilityTier.LIMITED -> "May fill soon — book early if you need a bay."
            ParkingAvailabilityTier.FULL -> "Site may be full — book anyway or pick another stop."
        }

    fun emphasizesTravis(tier: ParkingAvailabilityTier?): Boolean =
        tier == ParkingAvailabilityTier.AMPLE

    fun usesSecondaryBookStyle(tier: ParkingAvailabilityTier?): Boolean =
        tier == ParkingAvailabilityTier.FULL
}
