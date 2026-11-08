package com.routefinder.fleetdriver.nav

/** Lane arrow direction for junction guidance strips. */
enum class LaneArrow {
    STRAIGHT,
    SLIGHT_LEFT,
    LEFT,
    SLIGHT_RIGHT,
    RIGHT,
    MERGE,
    UNKNOWN,
}

/** Whether guidance came from OSM tags or a heuristic estimate. */
enum class LaneGuidanceSource {
    OSM,
    HEURISTIC,
    UNKNOWN,
}

/** Structured lane guidance for a maneuver. */
data class LaneGuidance(
    /** Lanes ordered left-to-right at the junction. */
    val lanes: List<LaneArrow>,
    /** Indices into [lanes] that the driver should use. */
    val recommendedIndices: List<Int>,
    val source: LaneGuidanceSource = LaneGuidanceSource.UNKNOWN,
) {
    /** Human-readable guidance for voice and compact labels. */
    val guidanceText: String
        get() {
            if (lanes.isEmpty()) return "Follow road"
            if (recommendedIndices.size == 1) {
                val index = recommendedIndices.first()
                if (index !in lanes.indices) return "Follow road"
                val laneNumber = index + 1
                return when (lanes[index]) {
                    LaneArrow.LEFT, LaneArrow.SLIGHT_LEFT ->
                        if (laneNumber == 1) "Use the left lane" else "Use lane $laneNumber"
                    LaneArrow.RIGHT, LaneArrow.SLIGHT_RIGHT ->
                        if (laneNumber == lanes.size) "Use the right lane" else "Use lane $laneNumber"
                    LaneArrow.MERGE -> "Merge"
                    else -> when {
                        laneNumber == 1 -> "Keep left"
                        laneNumber == lanes.size -> "Keep right"
                        else -> "Use lane $laneNumber"
                    }
                }
            }
            if (recommendedIndices.size > 1) {
                val numbers = recommendedIndices.joinToString(" and ") { "${it + 1}" }
                return "Use lanes $numbers"
            }
            return "Follow road"
        }

    /** Short symbol for UI strip (Unicode arrows). */
    fun symbol(forArrow: LaneArrow): String = when (forArrow) {
        LaneArrow.STRAIGHT -> "↑"
        LaneArrow.SLIGHT_LEFT -> "↖"
        LaneArrow.LEFT -> "←"
        LaneArrow.SLIGHT_RIGHT -> "↗"
        LaneArrow.RIGHT -> "→"
        LaneArrow.MERGE -> "⇉"
        LaneArrow.UNKNOWN -> "·"
    }
}
