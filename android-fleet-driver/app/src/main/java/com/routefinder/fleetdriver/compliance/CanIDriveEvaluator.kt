package com.routefinder.fleetdriver.compliance

import java.time.Instant
import kotlin.math.max
import kotlin.math.roundToInt

/** Advisory “Can I drive now?” answer — planning aid only. */
data class CanIDriveStatus(
    val canDrive: Boolean,
    val reason: String,
    val remainingContinuousDriveSeconds: Double,
    val remainingDailyDriveSeconds: Double = 0.0,
    val remainingWeeklyDriveSeconds: Double = 0.0,
    val remainingFortnightDriveSeconds: Double = 0.0,
    val usesImportedCard: Boolean = false,
    val usesPartnerAdvisory: Boolean = false,
)

/**
 * Evaluates Can-I-drive from partner webhook, imported card, and/or local HOS clock.
 * Priority when fresh (&lt; 24 h): partner → imported card → clock. Always appends legal-tacho disclaimer.
 * Partner/import gate continuous + daily + weekly.
 * Clock path also gates fortnight (90 h). WTD ≥ 60 h is advisory on the clock message only.
 * Mirrors iOS ``CanIDriveEvaluator``.
 */
object CanIDriveEvaluator {
    const val FRESHNESS_LIMIT_SECONDS = 24 * 3600L

    const val LEGAL_DISCLAIMER =
        "The digital tachograph is the legal record. This clock is a planning aid only."

    fun evaluate(
        partner: TachoCardSummary? = null,
        imported: TachoCardSummary? = null,
        clock: HosAdvisoryClock.Snapshot,
        now: Instant = Instant.now(),
    ): CanIDriveStatus {
        val continuous: Double
        val daily: Double
        val weekly: Double
        val fortnight: Double
        val applyFortnight: Boolean
        val sourceLabel: String
        val usesPartner: Boolean
        val usesImported: Boolean

        if (partner != null && ageSeconds(partner.importedAt, now) < FRESHNESS_LIMIT_SECONDS) {
            continuous = partner.remainingContinuousDriveSeconds
            daily = partner.remainingDailyDriveSeconds
            weekly = partner.remainingWeeklyDriveSeconds
            fortnight = 0.0
            applyFortnight = false
            sourceLabel = "partner advisory (${partner.sourceFileName})"
            usesPartner = true
            usesImported = false
        } else if (imported != null && ageSeconds(imported.importedAt, now) < FRESHNESS_LIMIT_SECONDS) {
            continuous = imported.remainingContinuousDriveSeconds
            daily = imported.remainingDailyDriveSeconds
            weekly = imported.remainingWeeklyDriveSeconds
            fortnight = 0.0
            applyFortnight = false
            sourceLabel = "imported card (${imported.sourceFileName})"
            usesPartner = false
            usesImported = true
        } else {
            continuous = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS - clock.continuousDriveSeconds
            daily = HosAdvisoryClock.effectiveDailyLimitSeconds(clock.usedDailyExtensionThisWeek) -
                clock.dailyDriveSeconds
            weekly = HosAdvisoryClock.WEEKLY_DRIVE_LIMIT_SECONDS - clock.weeklyDriveSeconds
            fortnight = HosAdvisoryClock.FORTNIGHT_DRIVE_LIMIT_SECONDS - clock.fortnightDriveSeconds
            applyFortnight = true
            sourceLabel = "advisory EU 561 clock"
            usesPartner = false
            usesImported = false
        }

        val canDrive = if (applyFortnight) {
            continuous > 0 && daily > 0 && weekly > 0 && fortnight > 0
        } else {
            continuous > 0 && daily > 0 && weekly > 0
        }

        val budgetReason = when {
            canDrive && applyFortnight ->
                "Yes — remaining continuous ${format(continuous)}, daily ${format(daily)}, " +
                    "weekly ${format(weekly)}, fortnight ${format(fortnight)} from $sourceLabel."
            canDrive ->
                "Yes — remaining continuous ${format(continuous)}, daily ${format(daily)}, " +
                    "weekly ${format(weekly)} from $sourceLabel."
            continuous <= 0 ->
                "No — continuous drive remaining is exhausted ($sourceLabel). Take a mandatory break."
            daily <= 0 ->
                "No — daily drive remaining is exhausted ($sourceLabel). End the driving day."
            weekly <= 0 ->
                "No — weekly drive remaining is exhausted ($sourceLabel). End the driving week."
            else ->
                "No — fortnight drive remaining is exhausted ($sourceLabel). End the driving fortnight."
        }
        return CanIDriveStatus(
            canDrive = canDrive,
            reason = "$budgetReason $LEGAL_DISCLAIMER",
            remainingContinuousDriveSeconds = continuous,
            remainingDailyDriveSeconds = daily,
            remainingWeeklyDriveSeconds = weekly,
            remainingFortnightDriveSeconds = fortnight,
            usesImportedCard = usesImported,
            usesPartnerAdvisory = usesPartner,
        )
    }

    private fun ageSeconds(importedAt: Instant, now: Instant): Long =
        max(0L, now.epochSecond - importedAt.epochSecond)

    private fun format(seconds: Double): String {
        val totalMinutes = max(0, (seconds / 60.0).roundToInt())
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
    }
}
