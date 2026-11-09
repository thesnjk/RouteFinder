package com.routefinder.fleetdriver.compliance

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class CanIDriveEvaluatorTest {
    @Test
    fun prefersFreshPartnerOverExhaustedClock() {
        val partner = TachoCardSummary(
            remainingContinuousDriveSeconds = 100.0,
            remainingDailyDriveSeconds = 200.0,
            remainingWeeklyDriveSeconds = 1_000.0,
            importedAt = Instant.now(),
            sourceFileName = "partner-webhook (samsara)",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS,
            dailyDriveSeconds = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS,
        )
        val status = CanIDriveEvaluator.evaluate(partner = partner, clock = clock)
        assertTrue(status.canDrive)
        assertTrue(status.usesPartnerAdvisory)
        assertFalse(status.usesImportedCard)
        assertEquals(100.0, status.remainingContinuousDriveSeconds, 0.01)
        assertEquals(200.0, status.remainingDailyDriveSeconds, 0.01)
        assertEquals(1_000.0, status.remainingWeeklyDriveSeconds, 0.01)
        assertTrue(status.reason.contains("partner"))
        assertTrue(status.reason.contains("weekly"))
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
    }

    @Test
    fun weeklyExhaustedBlocksDriveEvenWithContinuousAndDaily() {
        val imported = TachoCardSummary(
            remainingContinuousDriveSeconds = 500.0,
            remainingDailyDriveSeconds = 1_000.0,
            remainingWeeklyDriveSeconds = 0.0,
            importedAt = Instant.now(),
            sourceFileName = "card.json",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = 0.0,
        )
        val status = CanIDriveEvaluator.evaluate(imported = imported, clock = clock)
        assertFalse(status.canDrive)
        assertTrue(status.usesImportedCard)
        assertTrue(status.reason.contains("weekly"))
    }

    @Test
    fun fallsBackToClockWhenPartnerStale() {
        val partner = TachoCardSummary(
            remainingContinuousDriveSeconds = 5_000.0,
            remainingDailyDriveSeconds = 5_000.0,
            importedAt = Instant.now().minusSeconds(25 * 3600),
            sourceFileName = "partner-webhook (geotab)",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS,
            dailyDriveSeconds = 0.0,
        )
        val status = CanIDriveEvaluator.evaluate(partner = partner, clock = clock)
        assertFalse(status.canDrive)
        assertFalse(status.usesPartnerAdvisory)
        assertFalse(status.usesImportedCard)
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
    }

    @Test
    fun usesFreshImportedCardOverExhaustedClock() {
        val imported = TachoCardSummary(
            remainingContinuousDriveSeconds = 500.0,
            remainingDailyDriveSeconds = 1_000.0,
            remainingWeeklyDriveSeconds = 10_000.0,
            importedAt = Instant.now(),
            sourceFileName = "card.json",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS,
            dailyDriveSeconds = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS,
        )
        val status = CanIDriveEvaluator.evaluate(imported = imported, clock = clock)
        assertTrue(status.canDrive)
        assertTrue(status.usesImportedCard)
        assertFalse(status.usesPartnerAdvisory)
        assertEquals(500.0, status.remainingContinuousDriveSeconds, 0.01)
        assertTrue(status.reason.contains("imported card"))
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
    }

    @Test
    fun fallsBackToClockWhenImportStale() {
        val imported = TachoCardSummary(
            remainingContinuousDriveSeconds = 5_000.0,
            remainingDailyDriveSeconds = 5_000.0,
            remainingWeeklyDriveSeconds = 10_000.0,
            importedAt = Instant.now().minusSeconds(25 * 3600),
            sourceFileName = "old.json",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS,
            dailyDriveSeconds = 0.0,
        )
        val status = CanIDriveEvaluator.evaluate(imported = imported, clock = clock)
        assertFalse(status.canDrive)
        assertFalse(status.usesImportedCard)
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
    }

    @Test
    fun prefersFreshPartnerOverImport() {
        val partner = TachoCardSummary(
            remainingContinuousDriveSeconds = 100.0,
            remainingDailyDriveSeconds = 200.0,
            remainingWeeklyDriveSeconds = 1_000.0,
            importedAt = Instant.now(),
            sourceFileName = "partner-webhook (samsara)",
        )
        val imported = TachoCardSummary(
            remainingContinuousDriveSeconds = 9_000.0,
            remainingDailyDriveSeconds = 9_000.0,
            remainingWeeklyDriveSeconds = 10_000.0,
            importedAt = Instant.now(),
            sourceFileName = "card.json",
        )
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = HosAdvisoryClock.CONTINUOUS_DRIVE_LIMIT_SECONDS,
            dailyDriveSeconds = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS,
        )
        val status = CanIDriveEvaluator.evaluate(
            partner = partner,
            imported = imported,
            clock = clock,
        )
        assertTrue(status.canDrive)
        assertTrue(status.usesPartnerAdvisory)
        assertFalse(status.usesImportedCard)
        assertEquals(100.0, status.remainingContinuousDriveSeconds, 0.01)
        assertTrue(status.reason.contains("partner"))
    }

    @Test
    fun requiresBothContinuousAndDaily() {
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = HosAdvisoryClock.DAILY_DRIVE_LIMIT_SECONDS,
        )
        val status = CanIDriveEvaluator.evaluate(partner = null, clock = clock)
        assertFalse(status.canDrive)
        assertFalse(status.usesPartnerAdvisory)
        assertFalse(status.usesImportedCard)
    }

    @Test
    fun clockPathGatesWeeklyBudget() {
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = 0.0,
            weeklyDriveSeconds = HosAdvisoryClock.WEEKLY_DRIVE_LIMIT_SECONDS,
        )
        val status = CanIDriveEvaluator.evaluate(partner = null, clock = clock)
        assertFalse(status.canDrive)
        assertFalse(status.usesPartnerAdvisory)
        assertFalse(status.usesImportedCard)
        assertTrue(status.reason.contains("weekly"))
        assertEquals(0.0, status.remainingWeeklyDriveSeconds, 0.01)
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
    }

    @Test
    fun clockPathReportsWeeklyRemainingWhenFresh() {
        val clock = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = 0.0,
            dailyDriveSeconds = 0.0,
            weeklyDriveSeconds = 0.0,
        )
        val status = CanIDriveEvaluator.evaluate(partner = null, clock = clock)
        assertTrue(status.canDrive)
        assertTrue(status.reason.contains("weekly"))
        assertEquals(
            HosAdvisoryClock.WEEKLY_DRIVE_LIMIT_SECONDS,
            status.remainingWeeklyDriveSeconds,
            0.01,
        )
    }

    @Test
    fun partnerAdvisoryMapsToCardSummaryAndParsesJson() {
        val advisory = PartnerTachoAdvisory(
            remainingContinuousDriveSeconds = 1_200.0,
            remainingDailyDriveSeconds = 3_600.0,
            provider = "geotab",
            vehicleLabel = "Artic",
        )
        val summary = advisory.asCardSummary()
        assertEquals(1_200.0, summary.remainingContinuousDriveSeconds, 0.01)
        assertEquals("Artic", summary.cardNumber)
        assertTrue(summary.sourceFileName.contains("geotab"))

        val json = JSONObject(
            """
            {
              "remainingContinuousDriveSeconds": 900,
              "remainingDailyDriveSeconds": 1800,
              "remainingWeeklyDriveSeconds": 7200,
              "recordedAt": "2026-10-28T08:00:00Z",
              "provider": "samsara",
              "vehicleLabel": "Unit 12"
            }
            """.trimIndent(),
        )
        val parsed = PartnerTachoAdvisory.fromJson(json)
        assertEquals(900.0, parsed.remainingContinuousDriveSeconds, 0.01)
        assertEquals(1_800.0, parsed.remainingDailyDriveSeconds, 0.01)
        assertEquals(7_200.0, parsed.remainingWeeklyDriveSeconds!!, 0.01)
        assertEquals("samsara", parsed.provider)
        assertEquals("Unit 12", parsed.vehicleLabel)
    }
}
