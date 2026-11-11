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

    @Test
    fun toSnapshotJson_includesPredictedLayby() {
        val layby = predictedLaybyJson(
            stopId = "m1-watford-gap",
            label = "M1 J18 Watford Gap",
            latitude = 52.306,
            longitude = -1.122,
            distanceRemainingMeters = 4_500.0,
            occupancyPrior = "low",
            estimatedArrivalSeconds = 204.5,
        )
        val json = sampleTrip().toSnapshotJson(predictedLayby = layby)
        assertTrue(json.has("predictedLayby"))
        val decoded = json.getJSONObject("predictedLayby")
        assertEquals("low", decoded.getString("occupancyPrior"))
        assertEquals(4_500.0, decoded.getDouble("distanceRemainingMeters"), 0.01)
        val stop = decoded.getJSONObject("stop")
        assertEquals("M1 J18 Watford Gap", stop.getString("label"))
        assertEquals(52.306, stop.getJSONObject("coordinate").getDouble("latitude"), 0.0001)
        assertEquals(-1.122, stop.getJSONObject("coordinate").getDouble("longitude"), 0.0001)
    }

    @Test
    fun toSnapshotJson_omitsPredictedLaybyWhenNull() {
        val json = sampleTrip().toSnapshotJson()
        assertFalse(json.has("predictedLayby"))
    }
}
