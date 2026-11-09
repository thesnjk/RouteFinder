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
