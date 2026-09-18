package com.routefinder.fleetdriver.routing

import com.routefinder.fleetdriver.nav.TurnInstruction
import com.routefinder.fleetdriver.nav.TurnManeuver
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import org.json.JSONObject

data class OrsRouteResult(
    val coordinates: List<LatLon>,
    val distanceMeters: Double,
    val durationSeconds: Double,
    val instructions: List<TurnInstruction>,
)

/** Parses ORS GeoJSON directions responses and maps steps to turn instructions. */
object OrsResponseParser {
    fun parse(json: JSONObject): OrsRouteResult {
        val features = json.optJSONArray("features")
            ?: error("ORS response missing features")
        if (features.length() == 0) error("ORS returned no route features")

        val allCoords = mutableListOf<LatLon>()
        var totalDistance = 0.0
        var totalDuration = 0.0
        val maneuvers = mutableListOf<ExternalManeuver>()

        for (fi in 0 until features.length()) {
            val feature = features.getJSONObject(fi)
            val geometry = feature.optJSONObject("geometry")
            if (geometry != null && geometry.optString("type") == "LineString") {
                val coords = geometry.getJSONArray("coordinates")
                for (i in 0 until coords.length()) {
                    val pair = coords.getJSONArray(i)
                    if (pair.length() < 2) continue
                    val elev = if (pair.length() >= 3) pair.getDouble(2) else null
                    allCoords.add(
                        LatLon(
                            latitude = pair.getDouble(1),
                            longitude = pair.getDouble(0),
                            elevationMeters = elev,
                        ),
                    )
                }
            }
            val properties = feature.optJSONObject("properties") ?: continue
            val summary = properties.optJSONObject("summary")
            if (summary != null) {
                totalDistance += summary.optDouble("distance", 0.0)
                totalDuration += summary.optDouble("duration", 0.0)
            }
            val segments = properties.optJSONArray("segments") ?: continue
            for (si in 0 until segments.length()) {
                val steps = segments.getJSONObject(si).optJSONArray("steps") ?: continue
                for (sti in 0 until steps.length()) {
                    val step = steps.getJSONObject(sti)
                    maneuvers.add(
                        ExternalManeuver(
                            instruction = step.optString("instruction", "Continue"),
                            distanceMeters = step.optDouble("distance", 0.0),
                            durationSeconds = step.optDouble("duration", 0.0),
                            stepType = if (step.has("type")) step.getInt("type") else null,
                        ),
                    )
                }
            }
        }

        val instructions = mapManeuvers(maneuvers, allCoords)
        return OrsRouteResult(
            coordinates = allCoords,
            distanceMeters = totalDistance,
            durationSeconds = totalDuration,
            instructions = instructions,
        )
    }

    fun mapManeuvers(
        maneuvers: List<ExternalManeuver>,
        coordinates: List<LatLon>,
    ): List<TurnInstruction> {
        if (maneuvers.isEmpty()) return emptyList()
        val instructions = mutableListOf<TurnInstruction>()
        var cumulative = 0.0
        maneuvers.forEachIndexed { index, maneuver ->
            val type = mapStepType(maneuver.stepType, maneuver.instruction)
            val bearing = bearingForStep(index, type, coordinates, cumulative)
            instructions.add(
                TurnInstruction(
                    maneuver = type,
                    roadName = roadName(maneuver.instruction),
                    distanceMeters = maneuver.distanceMeters,
                    bearing = bearing,
                ),
            )
            cumulative += maneuver.distanceMeters
        }
        if (instructions.lastOrNull()?.maneuver != TurnManeuver.ARRIVE && coordinates.isNotEmpty()) {
            val lastBearing =
                if (coordinates.size >= 2) {
                    bearingBetween(coordinates[coordinates.size - 2], coordinates.last())
                } else {
                    0.0
                }
            instructions.add(
                TurnInstruction(
                    maneuver = TurnManeuver.ARRIVE,
                    roadName = null,
                    distanceMeters = 0.0,
                    bearing = lastBearing,
                ),
            )
        }
        return instructions
    }

    fun mapStepType(type: Int?, instruction: String): TurnManeuver {
        if (type == null) return classifyFromInstruction(instruction)
        return when (type) {
            0 -> TurnManeuver.STRAIGHT
            in 1..5 -> TurnManeuver.DEPART
            6 -> TurnManeuver.STRAIGHT
            7, 8 -> TurnManeuver.SLIGHT_RIGHT
            9, 10 -> TurnManeuver.RIGHT
            11, 12 -> TurnManeuver.SHARP_RIGHT
            13, 14 -> TurnManeuver.U_TURN
            15, 16 -> TurnManeuver.SLIGHT_LEFT
            17, 18 -> TurnManeuver.LEFT
            19, 20 -> TurnManeuver.SHARP_LEFT
            in 21..51 -> TurnManeuver.ROUNDABOUT
            in 100..149 -> TurnManeuver.ARRIVE
            else -> classifyFromInstruction(instruction)
        }
    }

    private fun classifyFromInstruction(instruction: String): TurnManeuver {
        val lower = instruction.lowercase()
        return when {
            "arrive" in lower || "destination" in lower -> TurnManeuver.ARRIVE
            "start" in lower || "head" in lower -> TurnManeuver.DEPART
            "u-turn" in lower || "uturn" in lower -> TurnManeuver.U_TURN
            "roundabout" in lower -> TurnManeuver.ROUNDABOUT
            "sharp left" in lower -> TurnManeuver.SHARP_LEFT
            "sharp right" in lower -> TurnManeuver.SHARP_RIGHT
            "slight left" in lower -> TurnManeuver.SLIGHT_LEFT
            "slight right" in lower -> TurnManeuver.SLIGHT_RIGHT
            "left" in lower -> TurnManeuver.LEFT
            "right" in lower -> TurnManeuver.RIGHT
            else -> TurnManeuver.STRAIGHT
        }
    }

    private fun roadName(instruction: String): String? {
        val trimmed = instruction.trim()
        if (trimmed.isEmpty()) return null
        if (trimmed.lowercase().startsWith("head")) return null
        return trimmed
    }

    private fun bearingForStep(
        index: Int,
        maneuverType: TurnManeuver,
        coordinates: List<LatLon>,
        cumulativeDistance: Double,
    ): Double {
        if (coordinates.size < 2) return 0.0
        if (maneuverType == TurnManeuver.DEPART || index == 0) {
            return bearingBetween(coordinates[0], coordinates[1])
        }
        val targetIndex = coordinateIndex(cumulativeDistance, coordinates)
        val fromIndex = minOf(targetIndex, coordinates.size - 2)
        return bearingBetween(coordinates[fromIndex], coordinates[fromIndex + 1])
    }

    private fun coordinateIndex(distance: Double, coordinates: List<LatLon>): Int {
        if (coordinates.size < 2) return 0
        var travelled = 0.0
        for (i in 0 until coordinates.size - 1) {
            travelled += haversineMeters(coordinates[i], coordinates[i + 1])
            if (travelled >= distance) return i + 1
        }
        return coordinates.size - 1
    }

    fun bearingBetween(a: LatLon, b: LatLon): Double {
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val y = sin(dLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        val brng = Math.toDegrees(atan2(y, x))
        return (brng + 360.0) % 360.0
    }

    fun haversineMeters(a: LatLon, b: LatLon): Double {
        val r = 6_371_000.0
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(kotlin.math.sqrt(h), kotlin.math.sqrt(1 - h))
    }
}

data class ExternalManeuver(
    val instruction: String,
    val distanceMeters: Double,
    val durationSeconds: Double,
    val stepType: Int?,
)
