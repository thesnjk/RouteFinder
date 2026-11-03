package com.routefinder.fleetdriver.compliance

/**
 * Driver-facing parking / layby availability band (CoPilot-style color tiers).
 * Mirrors iOS ``ParkingAvailabilityTier``.
 */
enum class ParkingAvailabilityTier {
    /** Spaces likely available. */
    AMPLE,

    /** Mixed / uncertain availability. */
    LIMITED,

    /** Likely full or evening peak pressure. */
    FULL,
    ;

    /** Short chip label. */
    val displayLabel: String
        get() = when (this) {
            AMPLE -> "Spaces"
            LIMITED -> "Limited"
            FULL -> "Full"
        }

    companion object {
        /** Confidence at or above this maps to [AMPLE]. */
        const val AMPLE_CONFIDENCE_FLOOR = 0.70

        /** Confidence at or above this (and below ample) maps to [LIMITED]. */
        const val LIMITED_CONFIDENCE_FLOOR = 0.45

        /** Inverts occupancy prior (low occupancy → ample spaces). */
        fun fromOccupancyPrior(prior: LaybyOccupancyPrior): ParkingAvailabilityTier =
            when (prior) {
                LaybyOccupancyPrior.LOW -> AMPLE
                LaybyOccupancyPrior.MODERATE -> LIMITED
                LaybyOccupancyPrior.HIGH -> FULL
            }

        /** Maps post-adjust confidence into availability bands. */
        fun fromConfidence(confidence: Double): ParkingAvailabilityTier {
            val clamped = confidence.coerceIn(0.0, 1.0)
            return when {
                clamped >= AMPLE_CONFIDENCE_FLOOR -> AMPLE
                clamped >= LIMITED_CONFIDENCE_FLOOR -> LIMITED
                else -> FULL
            }
        }
    }
}
