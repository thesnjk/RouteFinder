package com.routefinder.fleetdriver.inspection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InspectionChecklistTest {
    @Test
    fun summary_countsDefectsAndRequiresReview() {
        val items = InspectionChecklistFactory.defaultItems().toMutableList()
        assertFalse(InspectionChecklistFactory.allZonesReviewed(items))
        items.indices.forEach { i ->
            items[i] = items[i].copy(status = InspectionItemStatus.PASS)
        }
        items[0] = items[0].copy(status = InspectionItemStatus.DEFECT, note = "Crack", photoBase64 = "abc")
        assertTrue(InspectionChecklistFactory.allZonesReviewed(items))
        val summary = InspectionChecklistFactory.summary(items, "Artic", "AB12 CDE")
        assertEquals(1, summary.defectCount)
        assertEquals(1, summary.photoCount)
        assertEquals("Artic", summary.vehicleLabel)
        // PdfDocument requires full Android runtime — skip byte assert in JVM unit tests.
    }
}
