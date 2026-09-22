package com.routefinder.fleetdriver.compliance

/**
 * Advisory EU 561 / UK WTD remaining-drive clock (not a legal tachograph).
 * Mirrors the spirit of iOS ``HosAdvisoryCoordinator`` for Android C2.
 */
object HosAdvisoryClock {
    const val CONTINUOUS_DRIVE_LIMIT_SECONDS = 4.5 * 3_600
    const val DAILY_DRIVE_LIMIT_SECONDS = 9.0 * 3_600
    const val REQUIRED_BREAK_SECONDS = 45 * 60

    data class Snapshot(
        val continuousDriveSeconds: Double,
        val dailyDriveSeconds: Double,
        val canDriveNow: Boolean,
        val message: String,
    )

    fun snapshot(
        continuousDriveSeconds: Double,
        dailyDriveSeconds: Double,
    ): Snapshot {
        val continuousLeft = CONTINUOUS_DRIVE_LIMIT_SECONDS - continuousDriveSeconds
        val dailyLeft = DAILY_DRIVE_LIMIT_SECONDS - dailyDriveSeconds
        val canDrive = continuousLeft > 0 && dailyLeft > 0
        val message = when {
            !canDrive && continuousLeft <= 0 ->
                "Can I drive? No — take ${REQUIRED_BREAK_SECONDS.toInt() / 60} min break (4.5h continuous)"
            !canDrive ->
                "Can I drive? No — daily drive limit reached"
            continuousLeft < 30 * 60 ->
                "Break soon — ~${(continuousLeft / 60).toInt()} min continuous remaining"
            else ->
                "Can drive — ${(continuousLeft / 60).toInt()} min continuous / ${(dailyLeft / 60).toInt()} min daily left"
        }
        return Snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
            canDriveNow = canDrive,
            message = message,
        )
    }
}
