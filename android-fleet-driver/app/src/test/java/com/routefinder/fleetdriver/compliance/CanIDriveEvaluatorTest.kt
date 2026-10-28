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
        assertEquals(100.0, status.remainingContinuousDriveSeconds, 0.01)
        assertTrue(status.reason.contains("partner"))
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
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
        assertTrue(status.reason.contains(CanIDriveEvaluator.LEGAL_DISCLAIMER))
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
