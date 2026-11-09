package com.routefinder.fleetdriver.hazard

/** Crowd / sensor hazard event kinds reported by drivers (iOS `HazardEventType` parity). */
enum class HazardEventType {
    CLOSURE,
    TRAFFIC,
    CAMERA,
    WEATHER,
    OTHER,
}

/** Severity of a hazard event for map / voice promotion. */
enum class HazardSeverity {
    LOW,
    MODERATE,
    HIGH,
}

/** A spatially scoped hazard event on the living map layer. */
data class HazardEvent(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Double,
    val type: HazardEventType,
    val severity: HazardSeverity,
    val validFromEpochMs: Long,
    val validToEpochMs: Long,
    val source: String,
)

/** A crowd report submitted by a driver near a location. */
data class CrowdReport(
    val id: String = java.util.UUID.randomUUID().toString(),
    val latitude: Double,
    val longitude: Double,
    val type: HazardEventType,
    val reporterId: String,
    val createdAtEpochMs: Long = System.currentTimeMillis(),
    val note: String? = null,
)

/** Along-route hazard alert for HUD / voice. */
data class HazardAheadAnnouncement(
    val id: String,
    val type: HazardEventType,
    val distanceRemainingMeters: Double,
    val message: String,
    val source: String,
)

/**
 * Prompt asking the reporter whether a hazard is still present
 * (iOS `CrowdReportStillTherePrompt` parity).
 */
data class CrowdReportStillTherePrompt(
    val id: String,
    val reportType: HazardEventType,
    val message: String,
) {
    companion object {
        /** Delay before showing the still-there dialog after a report. */
        const val PROMPT_DELAY_MS: Long = 45_000L

        /** Validity window for a confirmed still-there hazard pin. */
        const val CONFIRM_VALIDITY_MS: Long = 45L * 60L * 1000L

        /** Builds the dialog copy from an optional note and report type. */
        fun message(note: String?, reportType: HazardEventType): String {
            val trimmed = note?.trim().orEmpty()
            return if (trimmed.isNotEmpty()) {
                "Is “$trimmed” still there?"
            } else {
                "Is the ${reportType.name.lowercase()} report still there?"
            }
        }

        /**
         * Builds a HIGH-severity confirm pin for overlay merge after the driver
         * taps Still there.
         */
        fun confirmHazard(
            prompt: CrowdReportStillTherePrompt,
            latitude: Double,
            longitude: Double,
            nowEpochMs: Long = System.currentTimeMillis(),
        ): HazardEvent = HazardEvent(
            id = "crowd-confirm-${prompt.id}",
            latitude = latitude,
            longitude = longitude,
            radiusMeters = 90.0,
            type = prompt.reportType,
            severity = HazardSeverity.HIGH,
            validFromEpochMs = nowEpochMs,
            validToEpochMs = nowEpochMs + CONFIRM_VALIDITY_MS,
            source = "crowd:confirm",
        )
    }
}
