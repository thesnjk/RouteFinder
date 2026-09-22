package com.routefinder.fleetdriver.fleet

/**
 * Pure job-intake helpers mirroring iOS ``JobIntakeMapper`` / ``JobIntakePolicy``.
 */
object JobIntakeHandler {
    fun orderedStops(trip: FleetTrip): List<FleetTripStop> =
        trip.stops.sortedBy { it.sequence }

    fun shouldAutoFindRoute(trip: FleetTrip): Boolean =
        trip.jobBrief?.autoFindRoute ?: true

    fun shouldAutoRehearse(trip: FleetTrip): Boolean =
        trip.jobBrief?.autoRehearse ?: false
}
