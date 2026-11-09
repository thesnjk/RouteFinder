package com.routefinder.fleetdriver.hazard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LocalCrowdEventStoreTest {
    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun submitRoundTripPersists() {
        val file = tempFolder.newFile("reports.json")
        val store = LocalCrowdEventStore(file)
        val report = CrowdReport(
            latitude = 52.6,
            longitude = 1.3,
            type = HazardEventType.CLOSURE,
            reporterId = "local-driver",
            note = "cones",
        )
        store.submit(report)
        val loaded = LocalCrowdEventStore(file).allReports()
        assertEquals(1, loaded.size)
        assertEquals(report.id, loaded.first().id)
        assertEquals(HazardEventType.CLOSURE, loaded.first().type)
        assertEquals("cones", loaded.first().note)
    }

    @Test
    fun prunesReportsOlderThanRetention() {
        val file = tempFolder.newFile("reports.json")
        val store = LocalCrowdEventStore(file)
        val stale = CrowdReport(
            latitude = 52.6,
            longitude = 1.3,
            type = HazardEventType.TRAFFIC,
            reporterId = "local-driver",
            createdAtEpochMs = System.currentTimeMillis() - LocalCrowdEventStore.MAX_AGE_MS - 60_000,
        )
        store.submit(stale)
        val remaining = store.allReports()
        assertTrue(remaining.none { it.id == stale.id })
    }
}
