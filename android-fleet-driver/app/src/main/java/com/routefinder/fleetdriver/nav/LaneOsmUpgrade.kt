package com.routefinder.fleetdriver.nav

/** Detects heuristic/unknown → OSM lane upgrades for prepare TTS refire (iOS parity). */
object LaneOsmUpgrade {
    /**
     * Maneuver indices whose [TurnInstruction.laneGuidance] upgraded from non-OSM (or null) to OSM.
     * Indices align with Android voice prepare/execute announcement keys.
     */
    fun upgradedManeuverIndices(
        previous: List<TurnInstruction>,
        updated: List<TurnInstruction>,
    ): List<Int> {
        val result = ArrayList<Int>()
        for (index in updated.indices) {
            val newSource = updated[index].laneGuidance?.source
            if (newSource != LaneGuidanceSource.OSM) continue
            val priorSource = previous.getOrNull(index)?.laneGuidance?.source
            if (priorSource == LaneGuidanceSource.OSM) continue
            result.add(index)
        }
        return result
    }
}
