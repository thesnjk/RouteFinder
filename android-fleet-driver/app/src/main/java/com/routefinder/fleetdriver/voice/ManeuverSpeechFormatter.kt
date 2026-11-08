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
        val street = streetCallout(instruction)
        val lane = laneCallout(instruction)
        return when (tier) {
            AnnouncementTier.APPROACH -> {
                val suffix = roadSuffix(instruction, tier)
                buildString {
                    append("In 1.6 kilometres, ${phrase.lowercase()}$suffix")
                    if (lane != null) append(". $lane")
                }
            }
            AnnouncementTier.PREPARE -> {
                buildString {
                    append("In 400 metres, ${phrase.lowercase()}")
                    if (street != null) append(" onto $street")
                    if (lane != null) append(". $lane")
                }
            }
            AnnouncementTier.EXECUTE -> {
                if (instruction.maneuver == TurnManeuver.ARRIVE) return phrase
                buildString {
                    append(phrase)
                    if (street != null) append(" onto $street")
                    if (lane != null) append(". $lane")
                }
            }
        }
    }

    fun shouldSuppressVoice(maneuver: TurnManeuver, tier: AnnouncementTier): Boolean =
        when (maneuver) {
            TurnManeuver.STRAIGHT, TurnManeuver.DEPART -> true
            else -> false
        }

    private fun streetCallout(instruction: TurnInstruction): String? {
        if (instruction.maneuver == TurnManeuver.ARRIVE) return null
        val road = instruction.roadName?.trim().orEmpty()
        if (road.isEmpty()) return null
        if (road.lowercase().startsWith("turn") || road.lowercase().startsWith("keep") ||
            road.lowercase().startsWith("head")
        ) {
            return null
        }
        return road.take(40)
    }

    private fun laneCallout(instruction: TurnInstruction): String? {
        val guidance = instruction.laneGuidance ?: return null
        val text = guidance.guidanceText
        return text.takeUnless { it == "Follow road" }
    }

    private fun roadSuffix(instruction: TurnInstruction, tier: AnnouncementTier): String {
        if (tier != AnnouncementTier.APPROACH) return ""
        if (instruction.maneuver == TurnManeuver.ARRIVE) return ""
        val road = streetCallout(instruction) ?: return ""
        return " onto $road"
    }
}
