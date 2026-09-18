package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.nav.AnnouncementTier
import com.routefinder.fleetdriver.nav.TurnInstruction
import com.routefinder.fleetdriver.nav.TurnManeuver

/** Metric spoken / display labels for turn-by-turn (ports iOS ManeuverSpeechFormatter). */
object ManeuverSpeechFormatter {
    fun shortPhrase(maneuver: TurnManeuver): String = when (maneuver) {
        TurnManeuver.DEPART -> "Depart"
        TurnManeuver.STRAIGHT -> "Continue straight"
        TurnManeuver.SLIGHT_LEFT -> "Slight left"
        TurnManeuver.LEFT -> "Turn left"
        TurnManeuver.SHARP_LEFT -> "Sharp left"
        TurnManeuver.SLIGHT_RIGHT -> "Slight right"
        TurnManeuver.RIGHT -> "Turn right"
        TurnManeuver.SHARP_RIGHT -> "Sharp right"
        TurnManeuver.U_TURN -> "Make a U-turn"
        TurnManeuver.ROUNDABOUT -> "Enter the roundabout"
        TurnManeuver.ARRIVE -> "You have arrived"
    }

    fun spokenPrompt(instruction: TurnInstruction, tier: AnnouncementTier): String {
        val phrase = shortPhrase(instruction.maneuver)
        return when (tier) {
            AnnouncementTier.APPROACH -> {
                val suffix = roadSuffix(instruction, tier)
                "In 1.6 kilometres, ${phrase.lowercase()}$suffix"
            }
            AnnouncementTier.PREPARE -> "In 400 metres, ${phrase.lowercase()}"
            AnnouncementTier.EXECUTE -> {
                if (instruction.maneuver == TurnManeuver.ARRIVE) return phrase
                val road = instruction.roadName
                if (!road.isNullOrBlank() && !road.lowercase().startsWith("turn") &&
                    !road.lowercase().startsWith("keep")
                ) {
                    // Prefer short road fragment if instruction string is long.
                    val shortRoad = road.take(40)
                    "$phrase onto $shortRoad"
                } else {
                    phrase
                }
            }
        }
    }

    fun shouldSuppressVoice(maneuver: TurnManeuver, tier: AnnouncementTier): Boolean =
        when (maneuver) {
            TurnManeuver.STRAIGHT, TurnManeuver.DEPART -> true
            else -> false
        }

    private fun roadSuffix(instruction: TurnInstruction, tier: AnnouncementTier): String {
        if (tier != AnnouncementTier.APPROACH) return ""
        if (instruction.maneuver == TurnManeuver.ARRIVE) return ""
        val road = instruction.roadName?.takeIf { it.isNotBlank() } ?: return ""
        return " onto $road"
    }
}
