package com.routefinder.fleetdriver.nav

/** Turn maneuver kinds aligned with iOS TurnManeuver. */
enum class TurnManeuver {
    DEPART,
    STRAIGHT,
    SLIGHT_LEFT,
    LEFT,
    SHARP_LEFT,
    SLIGHT_RIGHT,
    RIGHT,
    SHARP_RIGHT,
    U_TURN,
    ROUNDABOUT,
    ARRIVE,
}

data class TurnInstruction(
    val maneuver: TurnManeuver,
    val roadName: String?,
    val distanceMeters: Double,
    val bearing: Double,
)

enum class NavigationPhase {
    IDLE,
    ROUTE_LOADED,
    NAVIGATING,
    COMPLETED,
}

data class RouteGeometry(
    val coordinates: List<com.routefinder.fleetdriver.routing.LatLon>,
    val totalLengthMeters: Double,
    val staticEtaSeconds: Double,
)

data class NavigationProgress(
    val remainingDistanceMeters: Double,
    val remainingEtaSeconds: Double,
    val traveledDistanceMeters: Double,
    val progressFraction: Double,
    val currentManeuverIndex: Int,
    val distanceToNextManeuverMeters: Double,
)

enum class AnnouncementTier {
    APPROACH,
    PREPARE,
    EXECUTE,
}
