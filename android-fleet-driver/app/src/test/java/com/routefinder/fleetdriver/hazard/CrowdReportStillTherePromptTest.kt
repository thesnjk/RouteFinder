package com.routefinder.fleetdriver.hazard

import org.junit.Assert.assertEquals
import org.junit.Test

class CrowdReportStillTherePromptTest {
    @Test
    fun messageUsesNoteWhenPresent() {
        val msg = CrowdReportStillTherePrompt.message(
            note = "  Cone in lane  ",
            reportType = HazardEventType.TRAFFIC,
        )
        assertEquals("Is “Cone in lane” still there?", msg)
    }

    @Test
    fun messageFallsBackToTypeWhenNoteBlank() {
        val msg = CrowdReportStillTherePrompt.message(
            note = "   ",
            reportType = HazardEventType.CLOSURE,
        )
        assertEquals("Is the closure report still there?", msg)
    }

    @Test
    fun confirmHazardUsesHighSeverityCrowdConfirmSourceAndTtl() {
        val prompt = CrowdReportStillTherePrompt(
            id = "report-1",
            reportType = HazardEventType.TRAFFIC,
            message = "Is the traffic report still there?",
        )
        val now = 1_700_000_000_000L
        val hazard = CrowdReportStillTherePrompt.confirmHazard(
            prompt = prompt,
            latitude = 51.5,
            longitude = -0.1,
            nowEpochMs = now,
        )
        assertEquals("crowd-confirm-report-1", hazard.id)
        assertEquals(51.5, hazard.latitude, 0.0)
        assertEquals(-0.1, hazard.longitude, 0.0)
        assertEquals(90.0, hazard.radiusMeters, 0.0)
        assertEquals(HazardEventType.TRAFFIC, hazard.type)
        assertEquals(HazardSeverity.HIGH, hazard.severity)
        assertEquals("crowd:confirm", hazard.source)
        assertEquals(now, hazard.validFromEpochMs)
        assertEquals(now + CrowdReportStillTherePrompt.CONFIRM_VALIDITY_MS, hazard.validToEpochMs)
    }
}
