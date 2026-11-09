package com.routefinder.fleetdriver.compliance

/**
 * Advisory EU 561 / UK WTD remaining-drive clock (not a legal tachograph).
 *
 * Mini duty-log MVP: Drive / Break / Off duty with continuous, daily, and weekly
 * budgets. Mirrors the spirit of iOS ``EU561HosClock`` without fortnight, WTD
 * extension, or a full coordinator port.
 */
object HosAdvisoryClock {
    const val CONTINUOUS_DRIVE_LIMIT_SECONDS = 4.5 * 3_600
    const val DAILY_DRIVE_LIMIT_SECONDS = 9.0 * 3_600
    const val WEEKLY_DRIVE_LIMIT_SECONDS = 56.0 * 3_600
    const val REQUIRED_BREAK_SECONDS = 45 * 60

    enum class DutyMode {
        DRIVING,
        BREAK_REST,
        OFF_DUTY,
    }

    /** Mutable duty-log state persisted by the navigation host. */
    data class State(
        val mode: DutyMode = DutyMode.OFF_DUTY,
        val continuousDriveSeconds: Double = 0.0,
        val dailyDriveSeconds: Double = 0.0,
        val weeklyDriveSeconds: Double = 0.0,
        val lastTransitionAtMillis: Long = 0L,
    )

    data class Snapshot(
        val continuousDriveSeconds: Double,
        val dailyDriveSeconds: Double,
        val weeklyDriveSeconds: Double = 0.0,
        val mode: DutyMode = DutyMode.OFF_DUTY,
        val canDriveNow: Boolean,
        val message: String,
    )

    /** Accrues elapsed drive time only while [State.mode] is [DutyMode.DRIVING]. */
    fun accrue(state: State, deltaSeconds: Double): State {
        if (state.mode != DutyMode.DRIVING || deltaSeconds <= 0) return state
        return state.copy(
            continuousDriveSeconds = state.continuousDriveSeconds + deltaSeconds,
            dailyDriveSeconds = state.dailyDriveSeconds + deltaSeconds,
            weeklyDriveSeconds = state.weeklyDriveSeconds + deltaSeconds,
        )
    }

    /**
     * Transitions duty mode. Accrues driving time between [State.lastTransitionAtMillis]
     * and [atMillis] when leaving [DutyMode.DRIVING].
     *
     * Break resets continuous; off-duty resets continuous + daily (advisory).
     */
    fun transition(state: State, mode: DutyMode, atMillis: Long): State {
        var next = state
        if (state.lastTransitionAtMillis > 0L && atMillis > state.lastTransitionAtMillis) {
            val elapsedSeconds = (atMillis - state.lastTransitionAtMillis) / 1_000.0
            next = accrue(next, elapsedSeconds)
        }
        next = next.copy(mode = mode, lastTransitionAtMillis = atMillis)
        return when (mode) {
            DutyMode.BREAK_REST -> next.copy(continuousDriveSeconds = 0.0)
            DutyMode.OFF_DUTY -> next.copy(
                continuousDriveSeconds = 0.0,
                dailyDriveSeconds = 0.0,
            )
            DutyMode.DRIVING -> next
        }
    }

    fun snapshot(state: State): Snapshot =
        snapshot(
            continuousDriveSeconds = state.continuousDriveSeconds,
            dailyDriveSeconds = state.dailyDriveSeconds,
            weeklyDriveSeconds = state.weeklyDriveSeconds,
            mode = state.mode,
        )

    fun snapshot(
        continuousDriveSeconds: Double,
        dailyDriveSeconds: Double,
        weeklyDriveSeconds: Double = 0.0,
        mode: DutyMode = DutyMode.OFF_DUTY,
    ): Snapshot {
        val continuousLeft = CONTINUOUS_DRIVE_LIMIT_SECONDS - continuousDriveSeconds
        val dailyLeft = DAILY_DRIVE_LIMIT_SECONDS - dailyDriveSeconds
        val weeklyLeft = WEEKLY_DRIVE_LIMIT_SECONDS - weeklyDriveSeconds
        val canDrive = continuousLeft > 0 && dailyLeft > 0 && weeklyLeft > 0
        val message = when {
            !canDrive && continuousLeft <= 0 ->
                "Can I drive? No — take ${REQUIRED_BREAK_SECONDS.toInt() / 60} min break (4.5h continuous)"
            !canDrive && dailyLeft <= 0 ->
                "Can I drive? No — daily drive limit reached"
            !canDrive ->
                "Can I drive? No — weekly drive limit reached (56h)"
            continuousLeft < 30 * 60 ->
                "Break soon — ~${(continuousLeft / 60).toInt()} min continuous remaining"
            else ->
                "Can drive — ${(continuousLeft / 60).toInt()} min continuous / " +
                    "${(dailyLeft / 60).toInt()} min daily / ${(weeklyLeft / 60).toInt()} min weekly left"
        }
        return Snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
            weeklyDriveSeconds = weeklyDriveSeconds,
            mode = mode,
            canDriveNow = canDrive,
            message = message,
        )
    }

    fun parseDutyMode(raw: String?): DutyMode =
        when (raw?.trim()?.uppercase()) {
            "DRIVING" -> DutyMode.DRIVING
            "BREAK_REST", "BREAK" -> DutyMode.BREAK_REST
            else -> DutyMode.OFF_DUTY
        }
}
