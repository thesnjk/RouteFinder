package com.routefinder.fleetdriver.compliance

import java.time.Instant
import kotlin.math.max
import kotlin.math.roundToInt

/** Advisory “Can I drive now?” answer — planning aid only. */
data class CanIDriveStatus(
    val canDrive: Boolean,
    val reason: String,
    val remainingContinuousDriveSeconds: Double,
    val usesImportedCard: Boolean = false,
    val usesPartnerAdvisory: Boolean = false,
)

/**
 * Evaluates Can-I-drive from partner webhook and/or local HOS clock.
 * Priority when fresh (&lt; 24 h): partner → clock. Always appends legal-tacho disclaimer.
 * Mirrors iOS ``CanIDriveEvaluator``.
 */
object CanIDriveEvaluator {
    const val FRESHNESS_LIMIT_SECONDS = 24 * 3600L

    const val LEGAL_DISCLAIMER =
        "The digital tachograph is the legal record. This clock is a planning aid only."

    fun evaluate(
        partner: TachoCardSummary? = null,
        clock: HosAdvisoryClock.Snapshot,
        now: Instant = Instant.now(),
    ): CanIDriveStatus {
        val continuous: Double
        val daily: Double
        val sourceLabel: String
        val usesPartner: Boolean

        if (partner != null && ageSeconds(partner.importedAt, now) < FRESHNESS_LIMIT_SECONDS) {
            continuous = partner.remainingContinuousDriveSeconds
            daily = partner.remainingDailyDriveSeconds
            sourceLabel = "partner advisory (${partner.sourceFileName})"
            usesPartner = true
        } else {
            val continuousLeft = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS - clock.continuousDriveSeconds
            val dailyLeft = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS - clock.dailyDriveSeconds
            continuous = continuousLeft
            daily = dailyLeft
            sourceLabel = "advisory EU 561 clock"
            usesPartner = false
        }

        val canDrive = continuous > 0 && daily > 0
        val budgetReason = when {
            canDrive ->
                "Yes — remaining continuous ${format(continuous)}, daily ${format(daily)} from $sourceLabel."
            continuous <= 0 ->
                "No — continuous drive remaining is exhausted ($sourceLabel). Take a mandatory break."
            else ->
                "No — daily drive remaining is exhausted ($sourceLabel). End the driving day."
        }
        return CanIDriveStatus(
            canDrive = canDrive,
            reason = "$budgetReason $LEGAL_DISCLAIMER",
            remainingContinuousDriveSeconds = continuous,
            usesImportedCard = false,
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
