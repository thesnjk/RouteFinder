package com.routefinder.fleetdriver.compliance

/**
 * Advisory EU 561 / UK WTD remaining-drive clock (not a legal tachograph).
 *
 * Duty-log: Drive / Break / Off duty with continuous, daily, weekly, and fortnight
 * budgets; once-per-week 10 h daily extension; WTD ≥ 60 h heads-up. Mirrors iOS
 * ``EU561HosClock`` without otherWork/availability modes or a full coordinator port.
 */
object HosAdvisoryClock {
    const val CONTINUOUS_DRIVE_LIMIT_SECONDS = 4.5 * 3_600
    const val DAILY_DRIVE_LIMIT_SECONDS = 9.0 * 3_600
    const val DAILY_DRIVE_EXTENDED_LIMIT_SECONDS = 10.0 * 3_600
    const val WEEKLY_DRIVE_LIMIT_SECONDS = 56.0 * 3_600
    const val FORTNIGHT_DRIVE_LIMIT_SECONDS = 90.0 * 3_600
    const val WTD_WEEKLY_HEADS_UP_SECONDS = 60.0 * 3_600
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
        val fortnightDriveSeconds: Double = 0.0,
        val weekWorkedSeconds: Double = 0.0,
        val lastTransitionAtMillis: Long = 0L,
        val usedDailyExtensionThisWeek: Boolean = false,
    )

    data class Snapshot(
        val continuousDriveSeconds: Double,
        val dailyDriveSeconds: Double,
        val weeklyDriveSeconds: Double = 0.0,
        val fortnightDriveSeconds: Double = 0.0,
        val weekWorkedSeconds: Double = 0.0,
        val mode: DutyMode = DutyMode.OFF_DUTY,
        val usedDailyExtensionThisWeek: Boolean = false,
        val effectiveDailyLimitSeconds: Double = DAILY_DRIVE_LIMIT_SECONDS,
        val wtdHeadsUp: Boolean = false,
        val canDriveNow: Boolean,
        val message: String,
    )

    fun effectiveDailyLimitSeconds(usedDailyExtensionThisWeek: Boolean): Double =
        if (usedDailyExtensionThisWeek) {
            DAILY_DRIVE_EXTENDED_LIMIT_SECONDS
        } else {
            DAILY_DRIVE_LIMIT_SECONDS
        }

    /** Accrues elapsed drive time only while [State.mode] is [DutyMode.DRIVING]. */
    fun accrue(state: State, deltaSeconds: Double): State {
        if (state.mode != DutyMode.DRIVING || deltaSeconds <= 0) return state
        return state.copy(
            continuousDriveSeconds = state.continuousDriveSeconds + deltaSeconds,
            dailyDriveSeconds = state.dailyDriveSeconds + deltaSeconds,
            weeklyDriveSeconds = state.weeklyDriveSeconds + deltaSeconds,
            fortnightDriveSeconds = state.fortnightDriveSeconds + deltaSeconds,
            weekWorkedSeconds = state.weekWorkedSeconds + deltaSeconds,
        )
    }

    /**
     * Transitions duty mode. Accrues driving time between [State.lastTransitionAtMillis]
     * and [atMillis] when leaving [DutyMode.DRIVING].
     *
     * Break resets continuous; off-duty resets continuous + daily (advisory).
     * Extension / fortnight / week-worked flags are not cleared.
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

    /**
     * Activates the once-per-week advisory daily extension to 10 h.
     * Used-seconds model: sets the flag so the effective daily limit becomes 10 h.
     */
    fun activateDailyExtension(state: State): State {
        if (state.usedDailyExtensionThisWeek) return state
        return state.copy(usedDailyExtensionThisWeek = true)
    }

    fun snapshot(state: State): Snapshot =
        snapshot(
            continuousDriveSeconds = state.continuousDriveSeconds,
            dailyDriveSeconds = state.dailyDriveSeconds,
            weeklyDriveSeconds = state.weeklyDriveSeconds,
            fortnightDriveSeconds = state.fortnightDriveSeconds,
            weekWorkedSeconds = state.weekWorkedSeconds,
            mode = state.mode,
            usedDailyExtensionThisWeek = state.usedDailyExtensionThisWeek,
        )

    fun snapshot(
        continuousDriveSeconds: Double,
        dailyDriveSeconds: Double,
        weeklyDriveSeconds: Double = 0.0,
        fortnightDriveSeconds: Double = 0.0,
        weekWorkedSeconds: Double = 0.0,
        mode: DutyMode = DutyMode.OFF_DUTY,
        usedDailyExtensionThisWeek: Boolean = false,
    ): Snapshot {
        val dailyLimit = effectiveDailyLimitSeconds(usedDailyExtensionThisWeek)
        val continuousLeft = CONTINUOUS_DRIVE_LIMIT_SECONDS - continuousDriveSeconds
        val dailyLeft = dailyLimit - dailyDriveSeconds
        val weeklyLeft = WEEKLY_DRIVE_LIMIT_SECONDS - weeklyDriveSeconds
        val fortnightLeft = FORTNIGHT_DRIVE_LIMIT_SECONDS - fortnightDriveSeconds
        val wtdHeadsUp = weekWorkedSeconds >= WTD_WEEKLY_HEADS_UP_SECONDS
        val canDrive =
            continuousLeft > 0 && dailyLeft > 0 && weeklyLeft > 0 && fortnightLeft > 0
        var message = when {
            !canDrive && continuousLeft <= 0 ->
                "Can I drive? No — take ${REQUIRED_BREAK_SECONDS.toInt() / 60} min break (4.5h continuous)"
            !canDrive && dailyLeft <= 0 ->
                if (usedDailyExtensionThisWeek) {
                    "Can I drive? No — extended daily drive limit reached (10h)"
                } else {
                    "Can I drive? No — daily drive limit reached"
                }
            !canDrive && weeklyLeft <= 0 ->
                "Can I drive? No — weekly drive limit reached (56h)"
            !canDrive ->
                "Can I drive? No — fortnight drive limit reached (90h)"
            continuousLeft < 30 * 60 ->
                "Break soon — ~${(continuousLeft / 60).toInt()} min continuous remaining"
            else -> {
                val dailyNote = if (usedDailyExtensionThisWeek) " (10h ext)" else ""
                "Can drive — ${(continuousLeft / 60).toInt()} min continuous / " +
                    "${(dailyLeft / 60).toInt()} min daily$dailyNote / " +
                    "${(weeklyLeft / 60).toInt()} min weekly / " +
                    "${(fortnightLeft / 60).toInt()} min fortnight left"
            }
        }
        if (wtdHeadsUp) {
            message = "$message WTD heads-up: weekly working time ≥ 60 h."
        }
        return Snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
            weeklyDriveSeconds = weeklyDriveSeconds,
            fortnightDriveSeconds = fortnightDriveSeconds,
            weekWorkedSeconds = weekWorkedSeconds,
            mode = mode,
            usedDailyExtensionThisWeek = usedDailyExtensionThisWeek,
            effectiveDailyLimitSeconds = dailyLimit,
            wtdHeadsUp = wtdHeadsUp,
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
