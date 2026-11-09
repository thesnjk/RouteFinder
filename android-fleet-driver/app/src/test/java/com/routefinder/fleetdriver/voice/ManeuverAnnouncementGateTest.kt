package com.routefinder.fleetdriver.voice

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ManeuverAnnouncementGateTest {
    @Test
    fun invalidatePrepareAllowsSecondPrepare() {
        val gate = ManeuverAnnouncementGate()
        assertTrue(gate.shouldAnnouncePrepare(2))
        gate.markPrepare(2)
        assertFalse(gate.shouldAnnouncePrepare(2))

        gate.invalidatePrepareForLaneUpgrade(2)
        assertNull(gate.lastPrepareIndex)
        assertTrue(gate.shouldAnnouncePrepare(2))
    }

    @Test
    fun invalidatePrepareNoOpsAfterExecute() {
        val gate = ManeuverAnnouncementGate()
        gate.markPrepare(1)
        gate.markExecute(1)
        gate.invalidatePrepareForLaneUpgrade(1)
        assertFalse(gate.shouldAnnouncePrepare(1))
        assertFalse(gate.shouldAnnounceExecute(1))
    }

    @Test
    fun invalidateIgnoresOtherManeuverIndex() {
        val gate = ManeuverAnnouncementGate()
        gate.markPrepare(3)
        gate.invalidatePrepareForLaneUpgrade(5)
        assertFalse(gate.shouldAnnouncePrepare(3))
    }
}
