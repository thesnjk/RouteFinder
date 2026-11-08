package com.routefinder.fleetdriver.nav

/**
 * Parses OSM `turn:lanes` / `lanes` tags into structured lane guidance.
 * Mirrors iOS ``TurnLanesParser``.
 */
object TurnLanesParser {
    /** Parses a `turn:lanes` tag value such as `left|through|right`. */
    fun parse(turnLanes: String, forManeuver: TurnManeuver? = null): LaneGuidance? {
        if (turnLanes.isBlank()) return null
        val laneTokens = turnLanes.split("|")
        if (laneTokens.isEmpty()) return null

        val lanes = mutableListOf<LaneArrow>()
        val recommended = mutableListOf<Int>()

        laneTokens.forEachIndexed { index, laneToken ->
            val subTokens = compoundSubTokens(laneToken)
            if (subTokens.isEmpty()) {
                lanes.add(LaneArrow.UNKNOWN)
                return@forEachIndexed
            }
            val displayToken = displaySubToken(subTokens, forManeuver)
            lanes.add(arrowForToken(displayToken))
            if (forManeuver != null) {
                if (subTokens.any { subTokenMatchesManeuver(it, forManeuver) }) {
                    recommended.add(index)
                }
            } else if (subTokens.any { isRecommended(it) }) {
                recommended.add(index)
            }
        }

        val indices = if (recommended.isEmpty()) {
            defaultRecommendedIndices(lanes, forManeuver)
        } else {
            recommended
        }
        return LaneGuidance(lanes = lanes, recommendedIndices = indices, source = LaneGuidanceSource.OSM)
    }

    /** Builds heuristic lane guidance from a maneuver when OSM data is unavailable. */
    fun heuristic(maneuver: TurnManeuver, laneCount: Int = 3): LaneGuidance {
        val count = laneCount.coerceAtLeast(1)
        val lanes = MutableList(count) { LaneArrow.STRAIGHT }
        val recommended = when (maneuver) {
            TurnManeuver.SLIGHT_LEFT, TurnManeuver.LEFT, TurnManeuver.SHARP_LEFT -> listOf(0)
            TurnManeuver.SLIGHT_RIGHT, TurnManeuver.RIGHT, TurnManeuver.SHARP_RIGHT ->
                listOf(lanes.lastIndex)
            TurnManeuver.U_TURN -> listOf(0)
            else -> listOf(lanes.size / 2)
        }
        for (index in recommended) {
            if (index in lanes.indices) {
                lanes[index] = arrowForManeuver(maneuver)
            }
        }
        return LaneGuidance(
            lanes = lanes,
            recommendedIndices = recommended,
            source = LaneGuidanceSource.HEURISTIC,
        )
    }

    private fun compoundSubTokens(laneToken: String): List<String> {
        val normalized = laneToken.split(";")
            .map { normalizeSubToken(it) }
            .filter { it.isNotEmpty() }
        if (normalized.isNotEmpty() && normalized.all { it == "none" }) {
            return listOf("none")
        }
        return normalized.filter { isRecommended(it) }
    }

    private fun normalizeSubToken(raw: String): String =
        raw.lowercase()
            .replace(" ", "")
            .replace("merge_to_left", "merge")
            .replace("merge_to_right", "merge")

    private fun displaySubToken(subTokens: List<String>, forManeuver: TurnManeuver?): String {
        if (forManeuver == null) return subTokens.firstOrNull().orEmpty()
        return subTokens.firstOrNull { subTokenMatchesManeuver(it, forManeuver) }
            ?: subTokens.firstOrNull().orEmpty()
    }

    private fun isRecommended(token: String): Boolean =
        token.isNotEmpty() && token != "none"

    private fun subTokenMatchesManeuver(token: String, maneuver: TurnManeuver): Boolean {
        val arrow = arrowForToken(token)
        return when (maneuver) {
            TurnManeuver.SLIGHT_LEFT ->
                arrow == LaneArrow.SLIGHT_LEFT || arrow == LaneArrow.LEFT
            TurnManeuver.LEFT, TurnManeuver.SHARP_LEFT, TurnManeuver.U_TURN ->
                arrow == LaneArrow.LEFT || arrow == LaneArrow.SLIGHT_LEFT
            TurnManeuver.SLIGHT_RIGHT ->
                arrow == LaneArrow.SLIGHT_RIGHT || arrow == LaneArrow.RIGHT
            TurnManeuver.RIGHT, TurnManeuver.SHARP_RIGHT ->
                arrow == LaneArrow.RIGHT || arrow == LaneArrow.SLIGHT_RIGHT
            TurnManeuver.STRAIGHT, TurnManeuver.ROUNDABOUT, TurnManeuver.DEPART ->
                arrow == LaneArrow.STRAIGHT || arrow == LaneArrow.MERGE
            TurnManeuver.ARRIVE -> false
        }
    }

    private fun arrowForToken(token: String): LaneArrow = when {
        token == "none" -> LaneArrow.UNKNOWN
        "slight_left" in token || token == "slightleft" -> LaneArrow.SLIGHT_LEFT
        "sharp_left" in token || token == "sharpleft" -> LaneArrow.LEFT
        "left" in token -> LaneArrow.LEFT
        "slight_right" in token || token == "slightright" -> LaneArrow.SLIGHT_RIGHT
        "sharp_right" in token || token == "sharpright" -> LaneArrow.RIGHT
        "right" in token -> LaneArrow.RIGHT
        "through" in token || "straight" in token -> LaneArrow.STRAIGHT
        "merge" in token -> LaneArrow.MERGE
        else -> LaneArrow.UNKNOWN
    }

    private fun arrowForManeuver(maneuver: TurnManeuver): LaneArrow = when (maneuver) {
        TurnManeuver.SLIGHT_LEFT -> LaneArrow.SLIGHT_LEFT
        TurnManeuver.LEFT, TurnManeuver.SHARP_LEFT -> LaneArrow.LEFT
        TurnManeuver.SLIGHT_RIGHT -> LaneArrow.SLIGHT_RIGHT
        TurnManeuver.RIGHT, TurnManeuver.SHARP_RIGHT -> LaneArrow.RIGHT
        TurnManeuver.U_TURN -> LaneArrow.LEFT
        else -> LaneArrow.STRAIGHT
    }

    private fun defaultRecommendedIndices(
        lanes: List<LaneArrow>,
        maneuver: TurnManeuver?,
    ): List<Int> {
        if (maneuver != null) {
            val index = lanes.indexOfFirst { arrowMatchesManeuver(it, maneuver) }
            if (index >= 0) return listOf(index)
        }
        val straightIndex = lanes.indexOfFirst { it == LaneArrow.STRAIGHT }
        if (straightIndex >= 0) return listOf(straightIndex)
        return listOf(lanes.size / 2)
    }

    private fun arrowMatchesManeuver(arrow: LaneArrow, maneuver: TurnManeuver): Boolean =
        subTokenMatchesManeuver(tokenForArrow(arrow), maneuver)

    private fun tokenForArrow(arrow: LaneArrow): String = when (arrow) {
        LaneArrow.STRAIGHT -> "through"
        LaneArrow.SLIGHT_LEFT -> "slight_left"
        LaneArrow.LEFT -> "left"
        LaneArrow.SLIGHT_RIGHT -> "slight_right"
        LaneArrow.RIGHT -> "right"
        LaneArrow.MERGE -> "merge"
        LaneArrow.UNKNOWN -> ""
    }
}
