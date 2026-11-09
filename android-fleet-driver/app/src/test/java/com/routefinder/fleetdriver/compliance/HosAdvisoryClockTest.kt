package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HosAdvisoryClockTest {
    @Test
    fun accrueOnlyWhileDriving() {
        val off = HosAdvisoryClock.State(mode = HosAdvisoryClock.DutyMode.OFF_DUTY)
        assertEquals(0.0, HosAdvisoryClock.accrue(off, 600.0).continuousDriveSeconds, 0.01)

        val driving = HosAdvisoryClock.State(mode = HosAdvisoryClock.DutyMode.DRIVING)
        val accrued = HosAdvisoryClock.accrue(driving, 600.0)
        assertEquals(600.0, accrued.continuousDriveSeconds, 0.01)
        assertEquals(600.0, accrued.dailyDriveSeconds, 0.01)
        assertEquals(600.0, accrued.weeklyDriveSeconds, 0.01)
    }

    @Test
    fun breakResetsContinuousOnly() {
        val state = HosAdvisoryClock.State(
            mode = HosAdvisoryClock.DutyMode.DRIVING,
            continuousDriveSeconds = 1_000.0,
            dailyDriveSeconds = 2_000.0,
            weeklyDriveSeconds = 3_000.0,
            lastTransitionAtMillis = 1_000L,
        )
        val next = HosAdvisoryClock.transition(
            state = state,
            mode = HosAdvisoryClock.DutyMode.BREAK_REST,
            atMillis = 1_000L,
        )
        assertEquals(HosAdvisoryClock.DutyMode.BREAK_REST, next.mode)
        assertEquals(0.0, next.continuousDriveSeconds, 0.01)
        assertEquals(2_000.0, next.dailyDriveSeconds, 0.01)
        assertEquals(3_000.0, next.weeklyDriveSeconds, 0.01)
    }

    @Test
    fun offDutyResetsContinuousAndDaily() {
        val state = HosAdvisoryClock.State(
            mode = HosAdvisoryClock.DutyMode.DRIVING,
            continuousDriveSeconds = 1_000.0,
            dailyDriveSeconds = 2_000.0,
            weeklyDriveSeconds = 3_000.0,
            lastTransitionAtMillis = 5_000L,
        )
        val next = HosAdvisoryClock.transition(
            state = state,
            mode = HosAdvisoryClock.DutyMode.OFF_DUTY,
            atMillis = 5_000L,
        )
        assertEquals(0.0, next.continuousDriveSeconds, 0.01)
        assertEquals(0.0, next.dailyDriveSeconds, 0.01)
        assertEquals(3_000.0, next.weeklyDriveSeconds, 0.01)
    }

    @Test
    fun transitionAccruesElapsedDrivingBeforeModeChange() {
        val state = HosAdvisoryClock.State(
            mode = HosAdvisoryClock.DutyMode.DRIVING,
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = 0.0,
            weeklyDriveSeconds = 0.0,
            lastTransitionAtMillis = 0L,
        )
        val started = HosAdvisoryClock.transition(
            state = state,
            mode = HosAdvisoryClock.DutyMode.DRIVING,
            atMillis = 10_000L,
        )
        val afterBreak = HosAdvisoryClock.transition(
            state = started,
            mode = HosAdvisoryClock.DutyMode.BREAK_REST,
            atMillis = 70_000L, // +60s
        )
        // Accrued 60s then break reset continuous
        assertEquals(0.0, afterBreak.continuousDriveSeconds, 0.01)
        assertEquals(60.0, afterBreak.dailyDriveSeconds, 0.01)
        assertEquals(60.0, afterBreak.weeklyDriveSeconds, 0.01)
    }

    @Test
    fun snapshotBlocksWhenWeeklyExhausted() {
        val snap = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = 0.0,
            weeklyDriveSeconds = HosAdvisoryClock.WEEKLY_DRIVE_LIMIT_SECONDS,
        )
        assertFalse(snap.canDriveNow)
        assertTrue(snap.message.contains("weekly", ignoreCase = true))
    }

    @Test
    fun snapshotIncludesWeeklyRemainingWhenFresh() {
        val snap = HosAdvisoryClock.snapshot(0.0, 0.0, 0.0)
        assertTrue(snap.canDriveNow)
        assertTrue(snap.message.contains("weekly", ignoreCase = true))
    }

    @Test
    fun parseDutyModeDefaultsToOffDuty() {
        assertEquals(HosAdvisoryClock.DutyMode.DRIVING, HosAdvisoryClock.parseDutyMode("driving"))
        assertEquals(HosAdvisoryClock.DutyMode.BREAK_REST, HosAdvisoryClock.parseDutyMode("BREAK"))
        assertEquals(HosAdvisoryClock.DutyMode.OFF_DUTY, HosAdvisoryClock.parseDutyMode(null))
    }
}
