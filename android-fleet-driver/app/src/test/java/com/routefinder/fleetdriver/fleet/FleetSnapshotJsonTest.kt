package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FleetSnapshotJsonTest {
    private fun sampleTrip(): FleetTrip =
        FleetTrip(
            id = "11111111-1111-1111-1111-111111111111",
            orgId = "22222222-2222-2222-2222-222222222222",
            vehicleId = "33333333-3333-3333-3333-333333333333",
            status = "accepted",
            stops = emptyList(),
            physicsETASeconds = null,
            updatedAt = "2026-09-25T12:00:00Z",
        )

    @Test
    fun toSnapshotJson_includesCappedPdf() {
        val pdf = "JVBERi0xLjQ=" // minimal-looking base64
        val json = sampleTrip().toSnapshotJson(inspectionReportPDFBase64 = pdf)
        assertEquals(pdf, json.getString("inspectionReportPDFBase64"))
    }

    @Test
    fun toSnapshotJson_truncatesOversizedPdf() {
        val oversized = "A".repeat(InspectionMediaBudget.maxPDFBase64Characters + 50)
        val json = sampleTrip().toSnapshotJson(inspectionReportPDFBase64 = oversized)
        val capped = json.getString("inspectionReportPDFBase64")
        assertEquals(InspectionMediaBudget.maxPDFBase64Characters, capped.length)
        assertTrue(capped.all { it == 'A' })
    }

    @Test
    fun cappedPDFBase64_returnsNullForEmpty() {
        assertNull(InspectionMediaBudget.cappedPDFBase64(""))
    }

    @Test
    fun toSnapshotJson_omitsPdfWhenNull() {
        val json = sampleTrip().toSnapshotJson()
        assertFalse(json.has("inspectionReportPDFBase64"))
    }
}
