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

    /**
     * Spoken prompt for a given tier and instruction.
     * Prepare/execute prefer lane-first phrasing when OSM/heuristic lanes are present (iOS parity).
     */
    fun spokenPrompt(instruction: TurnInstruction, tier: AnnouncementTier): String {
        val phrase = shortPhrase(instruction.maneuver)
        val laneText = laneCallout(instruction)
        val suffix = roadSuffix(instruction)

        return when (tier) {
            AnnouncementTier.APPROACH -> {
                if (laneText != null) {
                    "In 1.6 kilometres, ${laneText.lowercase()}$suffix"
                } else {
                    "In 1.6 kilometres, ${phrase.lowercase()}$suffix"
                }
            }
            AnnouncementTier.PREPARE -> {
                if (laneText != null) {
                    "In 400 metres, ${laneText.lowercase()}$suffix"
                } else {
                    "In 400 metres, ${phrase.lowercase()}$suffix"
                }
            }
            AnnouncementTier.EXECUTE -> {
                if (instruction.maneuver == TurnManeuver.ARRIVE) return phrase
                if (laneText != null) {
                    "$laneText, then ${phrase.lowercase()}$suffix"
                } else if (suffix.isNotEmpty()) {
                    "$phrase$suffix"
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

    private fun streetCallout(instruction: TurnInstruction): String? {
        if (instruction.maneuver == TurnManeuver.ARRIVE) return null
        val road = instruction.roadName?.trim().orEmpty()
        if (road.isEmpty()) return null
        val lower = road.lowercase()
        if (lower.startsWith("turn") || lower.startsWith("keep") || lower.startsWith("head")) {
            return null
        }
        return road.take(40)
    }

    private fun laneCallout(instruction: TurnInstruction): String? {
        val guidance = instruction.laneGuidance ?: return null
        val text = guidance.spokenLanePhrase()
        return text.takeUnless { it == "Follow the road" || it == "Follow road" }
    }

    /** ` onto {road}` when a street name is known (all announcement tiers — iOS parity). */
    private fun roadSuffix(instruction: TurnInstruction): String {
        if (instruction.maneuver == TurnManeuver.ARRIVE) return ""
        val road = streetCallout(instruction) ?: return ""
        return " onto $road"
    }
}
