package com.routefinder.fleetdriver.voice

/**
 * Tracks which maneuver indices have already received approach/prepare/execute TTS.
 * Pure logic so JVM unit tests can cover late-OSM prepare invalidation without Android TTS.
 */
class ManeuverAnnouncementGate {
    var lastApproachIndex: Int? = null
        private set
    var lastPrepareIndex: Int? = null
        private set
    var lastExecuteIndex: Int? = null
        private set

    fun reset() {
        lastApproachIndex = null
        lastPrepareIndex = null
        lastExecuteIndex = null
    }

    fun shouldAnnounceApproach(maneuverIndex: Int): Boolean = lastApproachIndex != maneuverIndex

    fun shouldAnnouncePrepare(maneuverIndex: Int): Boolean = lastPrepareIndex != maneuverIndex

    fun shouldAnnounceExecute(maneuverIndex: Int): Boolean = lastExecuteIndex != maneuverIndex

    fun markApproach(maneuverIndex: Int) {
        lastApproachIndex = maneuverIndex
    }

    fun markPrepare(maneuverIndex: Int) {
        lastPrepareIndex = maneuverIndex
    }

    fun markExecute(maneuverIndex: Int) {
        lastExecuteIndex = maneuverIndex
    }

    /**
     * Clears a spoken prepare so OSM-upgraded lane guidance can re-speak inside the prepare window.
     * No-ops when execute was already spoken for this maneuver index.
     */
    fun invalidatePrepareForLaneUpgrade(maneuverIndex: Int) {
        if (lastExecuteIndex == maneuverIndex) return
        if (lastPrepareIndex == maneuverIndex) {
            lastPrepareIndex = null
        }
    }
}
