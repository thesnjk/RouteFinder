package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsResponseParser
import kotlin.math.max
import kotlin.math.min

/** Holds active route geometry, instructions, and navigation phase. */
class NavigationSession {
    var phase: NavigationPhase = NavigationPhase.IDLE
        private set
    var geometry: RouteGeometry? = null
        private set
    var instructions: List<TurnInstruction> = emptyList()
        private set
    var progress: NavigationProgress? = null
        private set
    var physicsEtaSeconds: Double? = null

    fun loadRoute(geometry: RouteGeometry, instructions: List<TurnInstruction>) {
        this.geometry = geometry
        this.instructions = instructions
        this.progress = null
        this.physicsEtaSeconds = null
        phase = NavigationPhase.ROUTE_LOADED
    }

    fun startNavigation() {
        if (geometry == null) return
        phase = NavigationPhase.NAVIGATING
        val length = geometry!!.totalLengthMeters
        progress = NavigationProgress(
            remainingDistanceMeters = length,
            remainingEtaSeconds = geometry!!.staticEtaSeconds,
            traveledDistanceMeters = 0.0,
            progressFraction = 0.0,
            currentManeuverIndex = 0,
            distanceToNextManeuverMeters = instructions.firstOrNull()?.distanceMeters ?: length,
        )
    }

    fun stopNavigation() {
        progress = null
        phase = if (geometry == null) NavigationPhase.IDLE else NavigationPhase.ROUTE_LOADED
    }

    fun clear() {
        geometry = null
        instructions = emptyList()
        progress = null
        physicsEtaSeconds = null
        phase = NavigationPhase.IDLE
    }

    fun ingestPosition(lat: Double, lon: Double) {
        if (phase != NavigationPhase.NAVIGATING) return
        val geo = geometry ?: return
        val projection = RouteProgressTracker.project(
            position = LatLon(lat, lon),
            coordinates = geo.coordinates,
        ) ?: return
        val remaining = max(0.0, geo.totalLengthMeters - projection.arcLengthMeters)
        val fraction = if (geo.totalLengthMeters > 0) {
            min(1.0, projection.arcLengthMeters / geo.totalLengthMeters)
        } else {
            0.0
        }
        val eta = if (geo.totalLengthMeters > 1) {
            geo.staticEtaSeconds * (remaining / geo.totalLengthMeters)
        } else {
            0.0
        }
        val (maneuverIndex, distanceToNext) = RouteProgressTracker.maneuverAt(
            arcLengthMeters = projection.arcLengthMeters,
            instructions = instructions,
        )
        progress = NavigationProgress(
            remainingDistanceMeters = remaining,
            remainingEtaSeconds = eta,
            traveledDistanceMeters = projection.arcLengthMeters,
            progressFraction = fraction,
            currentManeuverIndex = maneuverIndex,
            distanceToNextManeuverMeters = distanceToNext,
        )
        if (remaining < 25.0) {
            phase = NavigationPhase.COMPLETED
        }
    }

    fun currentInstruction(): TurnInstruction? {
        val index = progress?.currentManeuverIndex ?: 0
        return instructions.getOrNull(index)
    }
}

object RouteProgressTracker {
    data class Projection(
        val arcLengthMeters: Double,
        val crossTrackMeters: Double,
    )

    fun project(
        position: LatLon,
        coordinates: List<LatLon>,
        crossTrackThresholdMeters: Double = 25.0,
    ): Projection? {
        if (coordinates.size < 2) return null
        var bestArc = 0.0
        var bestCross = Double.MAX_VALUE
        var travelled = 0.0
        for (i in 0 until coordinates.size - 1) {
            val a = coordinates[i]
            val b = coordinates[i + 1]
            val segLen = OrsResponseParser.haversineMeters(a, b)
            val projected = projectOnSegment(position, a, b, segLen)
            if (projected.crossTrack < bestCross) {
                bestCross = projected.crossTrack
                bestArc = travelled + projected.along
            }
            travelled += segLen
        }
        if (bestCross > crossTrackThresholdMeters) return null
        return Projection(arcLengthMeters = bestArc, crossTrackMeters = bestCross)
    }

    fun maneuverAt(
        arcLengthMeters: Double,
        instructions: List<TurnInstruction>,
    ): Pair<Int, Double> {
        if (instructions.isEmpty()) return 0 to 0.0
        var cumulative = 0.0
        instructions.forEachIndexed { index, instruction ->
            val end = cumulative + instruction.distanceMeters
            if (arcLengthMeters <= end || index == instructions.lastIndex) {
                return index to max(0.0, end - arcLengthMeters)
            }
            cumulative = end
        }
        return instructions.lastIndex to 0.0
    }

    private data class SegProj(val along: Double, val crossTrack: Double)

    private fun projectOnSegment(
        p: LatLon,
        a: LatLon,
        b: LatLon,
        segLen: Double,
    ): SegProj {
        if (segLen < 0.1) {
            return SegProj(0.0, OrsResponseParser.haversineMeters(p, a))
        }
        // Approximate local ENU projection for short UK segments.
        val ax = a.longitude
        val ay = a.latitude
        val bx = b.longitude
        val by = b.latitude
        val px = p.longitude
        val py = p.latitude
        val abx = bx - ax
        val aby = by - ay
        val apx = px - ax
        val apy = py - ay
        val ab2 = abx * abx + aby * aby
        val t = ((apx * abx + apy * aby) / ab2).coerceIn(0.0, 1.0)
        val cx = ax + t * abx
        val cy = ay + t * aby
        val cross = OrsResponseParser.haversineMeters(p, LatLon(cy, cx))
        return SegProj(along = t * segLen, crossTrack = cross)
    }
}
