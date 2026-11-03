package com.routefinder.fleetdriver.compliance

import java.util.Calendar

/** Hour-of-day occupancy prior for a layby (heuristic — not live sensor data). */
enum class LaybyOccupancyPrior {
    LOW,
    MODERATE,
    HIGH,
    ;

    val displayLabel: String
        get() = when (this) {
            LOW -> "low"
            MODERATE -> "moderate"
            HIGH -> "high"
        }

    companion object {
        /** Local hours treated as evening occupancy peak (17…21 inclusive). */
        val EVENING_PEAK_HOURS: IntRange = 17..21

        /**
         * Hour-of-day prior for laybys.
         * Evening peak → [HIGH]; daytime → [MODERATE]; overnight/early → [LOW].
         */
        fun forHour(hour: Int): LaybyOccupancyPrior {
            val multiplier = availabilityMultiplier(forHour = hour)
            return when {
                multiplier >= 0.95 -> LOW
                multiplier >= 0.75 -> MODERATE
                else -> HIGH
            }
        }

        /** Same multipliers as iOS ``ParkingOccupancyPrior.laybyAvailabilityMultiplier``. */
        fun availabilityMultiplier(forHour: Int): Double = when {
            forHour in EVENING_PEAK_HOURS -> 0.55
            forHour in 7..16 -> 0.78
            else -> 0.95
        }

        fun forNow(calendar: Calendar = Calendar.getInstance()): LaybyOccupancyPrior =
            forHour(calendar.get(Calendar.HOUR_OF_DAY))
    }
}

/** On-device crowd tap kind for a layby. */
enum class LaybyOccupancyKind {
    FULL,
    SPACES_AVAILABLE,
}
