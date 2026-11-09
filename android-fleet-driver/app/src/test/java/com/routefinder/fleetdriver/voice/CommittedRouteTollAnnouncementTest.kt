package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.routing.UKTollAdvisoryCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CommittedRouteTollAnnouncementTest {
    @Test
    fun summaryNilWhenEmpty() {
        assertNull(VoiceAssistResponseFormatter.committedRouteTollSummary(emptyList()))
        assertNull(VoiceAssistResponseFormatter.committedRouteTollAnnouncement(emptyList()))
    }

    @Test
    fun announcementIncludesIndicativeTotal() {
        val advisories = UKTollAdvisoryCatalog.all.filter {
            it.id == "dartford-crossing" || it.id == "m6-toll"
        }
        assertEquals(2, advisories.size)
        val summary = VoiceAssistResponseFormatter.committedRouteTollSummary(advisories)
        assertNotNull(summary)
        assertTrue(summary!!.contains("Dartford"))
        assertTrue(summary.contains("M6 Toll"))
        assertTrue(summary.contains("Indicative tolls"))

        val spoken = VoiceAssistResponseFormatter.committedRouteTollAnnouncement(advisories)
        assertNotNull(spoken)
        assertTrue(spoken!!.contains("Indicative only"))
        assertFalse(spoken == "No named tolls on this route.")
    }

    @Test
    fun signatureOrderIndependent() {
        val a = UKTollAdvisoryCatalog.all.first { it.id == "dartford-crossing" }
        val b = UKTollAdvisoryCatalog.all.first { it.id == "m6-toll" }
        val left = VoiceAssistResponseFormatter.tollRouteSignature(listOf(a, b))
        val right = VoiceAssistResponseFormatter.tollRouteSignature(listOf(b, a))
        assertEquals(left, right)
        assertTrue(left.isNotEmpty())
    }
}
