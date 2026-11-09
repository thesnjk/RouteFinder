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
    /**
     * Human-readable guidance for voice and compact labels.
     * Mirrors iOS ``ManeuverSpeechFormatter.spokenLanePhrase``.
     */
    val guidanceText: String
        get() = spokenLanePhrase()

    /** Spoken / display lane phrase (natural multi-lane wording). */
    fun spokenLanePhrase(): String {
        if (lanes.isEmpty()) return "Follow the road"
        val indices = recommendedIndices.sorted()
        if (indices.isEmpty()) return "Follow the road"

        if (indices.size == 1) {
            val index = indices.first()
            if (index !in lanes.indices) return "Follow the road"
            val laneCount = lanes.size
            return when (lanes[index]) {
                LaneArrow.LEFT, LaneArrow.SLIGHT_LEFT ->
                    if (index == 0) "Use the left lane" else "Use lane ${index + 1}"
                LaneArrow.RIGHT, LaneArrow.SLIGHT_RIGHT ->
                    if (index == laneCount - 1) "Use the right lane" else "Use lane ${index + 1}"
                LaneArrow.MERGE -> "Merge"
                else -> when {
                    index == 0 -> "Keep left"
                    index == laneCount - 1 -> "Keep right"
                    else -> "Use lane ${index + 1}"
                }
            }
        }

        val laneCount = lanes.size
        val isContiguousFromLeft = indices == (0 until indices.size).toList()
        val isContiguousFromRight =
            indices == ((laneCount - indices.size) until laneCount).toList()
        if (isContiguousFromLeft) {
            return if (indices.size == 2) {
                "Use the left two lanes"
            } else {
                "Use the left ${indices.size} lanes"
            }
        }
        if (isContiguousFromRight) {
            return if (indices.size == 2) {
                "Use the right two lanes"
            } else {
                "Use the right ${indices.size} lanes"
            }
        }
        val numbers = indices.joinToString(" and ") { "${it + 1}" }
        return "Use lanes $numbers"
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
