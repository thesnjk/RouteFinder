package com.routefinder.fleetdriver.nav

/**
 * Fuses kinetic / weather / hazard / roadworks / traffic / schedule / forecast / clearance
 * into advisories (iOS ``PredictiveRiskEngine`` parity).
 */
object PredictiveRiskEngine {
    enum class Kind { KINETIC, WEATHER, HAZARD, ROADWORKS, TRAFFIC, CLEARANCE }
    enum class Severity { INFO, CAUTION, SEVERE }

    data class Advisory(
        val id: String,
        val kind: Kind,
        val severity: Severity,
        val distanceRemainingMeters: Double,
        val message: String,
        val source: String,
    )

    data class Snapshot(
        val kineticMessage: String? = null,
        val kineticDistanceMeters: Double? = null,
        val weatherMessage: String? = null,
        val weatherDistanceMeters: Double? = null,
        val hazardMessage: String? = null,
        val hazardDistanceMeters: Double? = null,
        val hazardSevere: Boolean = false,
        val roadworksMessage: String? = null,
        val roadworksDistanceMeters: Double? = null,
        val trafficMessage: String? = null,
        val trafficDistanceMeters: Double? = null,
        val scheduleLateMessage: String? = null,
        val scheduleLateDistanceMeters: Double? = null,
        val forecastItems: List<Advisory> = emptyList(),
        val clearanceItems: List<Advisory> = emptyList(),
    )

    fun fuse(snapshot: Snapshot): List<Advisory> {
        val items = mutableListOf<Advisory>()

        // Severe forecast first so primaryAhead prefers them when severity ties break on distance.
        items += snapshot.forecastItems.filter { it.severity == Severity.SEVERE }

        snapshot.kineticMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "kinetic-${msg.hashCode()}",
                kind = Kind.KINETIC,
                severity = Severity.CAUTION,
                distanceRemainingMeters = snapshot.kineticDistanceMeters ?: 1_500.0,
                message = msg,
                source = "kinetic",
            )
        }
        snapshot.weatherMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "weather-${msg.hashCode()}",
                kind = Kind.WEATHER,
                severity = Severity.CAUTION,
                distanceRemainingMeters = snapshot.weatherDistanceMeters ?: 3_000.0,
                message = msg,
                source = "weather",
            )
        }
        snapshot.hazardMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "hazard-${msg.hashCode()}",
                kind = Kind.HAZARD,
                severity = if (snapshot.hazardSevere) Severity.SEVERE else Severity.CAUTION,
                distanceRemainingMeters = snapshot.hazardDistanceMeters ?: 1_200.0,
                message = msg,
                source = "hazard",
            )
        }
        snapshot.roadworksMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "roadworks-${msg.hashCode()}",
                kind = Kind.ROADWORKS,
                severity = Severity.CAUTION,
                distanceRemainingMeters = snapshot.roadworksDistanceMeters ?: 2_000.0,
                message = msg,
                source = "roadworks",
            )
        }
        snapshot.trafficMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "traffic-${msg.hashCode()}",
                kind = Kind.TRAFFIC,
                severity = Severity.CAUTION,
                distanceRemainingMeters = snapshot.trafficDistanceMeters ?: 2_500.0,
                message = msg,
                source = "traffic",
            )
        }
        snapshot.scheduleLateMessage?.trim()?.takeIf { it.isNotEmpty() }?.let { msg ->
            items += Advisory(
                id = "schedule-${msg.hashCode()}",
                kind = Kind.TRAFFIC,
                severity = Severity.CAUTION,
                distanceRemainingMeters = snapshot.scheduleLateDistanceMeters ?: 5_000.0,
                message = msg,
                source = "timeWindow",
            )
        }

        items += snapshot.forecastItems.filter { it.severity != Severity.SEVERE }
        items += snapshot.clearanceItems
        return items
    }

    fun primaryAhead(advisories: List<Advisory>, maxAheadMeters: Double = 8_000.0): Advisory? =
        advisories
            .filter { it.distanceRemainingMeters > 0 && it.distanceRemainingMeters <= maxAheadMeters }
            .maxWithOrNull(
                compareBy<Advisory> { it.severity.ordinal }
                    .thenBy { -it.distanceRemainingMeters },
            )
}
