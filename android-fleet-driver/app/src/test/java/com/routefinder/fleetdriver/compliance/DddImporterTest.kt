package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class DddImporterTest {
    @Test
    fun parsesSimpleJSONExport() {
        val json = """
            {
              "remainingContinuousDriveSeconds": 7200,
              "remainingDailyDriveSeconds": 18000,
              "remainingWeeklyDriveSeconds": 140000,
              "cardNumber": "GB123456789012"
            }
        """.trimIndent().toByteArray()
        val importer = DddImporter(now = { Instant.ofEpochSecond(1_700_000_000) })
        val summary = importer.importDriverCard(json)
        assertEquals(7200.0, summary.remainingContinuousDriveSeconds, 0.01)
        assertEquals(18000.0, summary.remainingDailyDriveSeconds, 0.01)
        assertEquals(140000.0, summary.remainingWeeklyDriveSeconds, 0.01)
        assertEquals("GB123456789012", summary.cardNumber)
        assertEquals("import", summary.sourceFileName)
    }

    @Test
    fun parsesRemainingDriveSecondsAlias() {
        val json = """
            {"remainingDriveSeconds": 3600, "remainingDailyDriveSeconds": 9000, "remainingWeeklyDriveSeconds": 50000}
        """.trimIndent().toByteArray()
        val summary = DddImporter().importDriverCard(json, sourceFileName = "fixture.json")
        assertEquals(3600.0, summary.remainingContinuousDriveSeconds, 0.01)
        assertEquals("fixture.json", summary.sourceFileName)
    }

    @Test
    fun rejectsUnrecognizedBinaryWithoutSidecar() {
        val binary = byteArrayOf(0x00, 0x01, 0x02, 0xFF.toByte(), 0xFE.toByte(), 0x76, 0x75)
        try {
            DddImporter().importDriverCard(binary, sourceFileName = "card.ddd")
            throw AssertionError("expected UnrecognizedBinaryDDD")
        } catch (e: TachoImportError.UnrecognizedBinaryDDD) {
            assertTrue(e.message!!.contains("remainingDriveSeconds"))
        }
    }

    @Test
    fun usesSidecarJSONForBinaryDDD() {
        val binary = byteArrayOf(0x00, 0x01, 0x02, 0xFF.toByte(), 0xFE.toByte())
        val sidecar = """
            {"remainingContinuousDriveSeconds": 1000, "remainingDailyDriveSeconds": 2000, "remainingWeeklyDriveSeconds": 3000}
        """.trimIndent().toByteArray()
        val summary = DddImporter().importDriverCard(
            data = binary,
            sourceFileName = "card.ddd",
            sidecarData = sidecar,
        )
        assertEquals(1000.0, summary.remainingContinuousDriveSeconds, 0.01)
        assertEquals(2000.0, summary.remainingDailyDriveSeconds, 0.01)
    }

    @Test
    fun defaultsWeeklyWhenOnlyContinuousAndDailyPresent() {
        val json = """
            {"remainingContinuousDriveSeconds": 100, "remainingDailyDriveSeconds": 200}
        """.trimIndent().toByteArray()
        val summary = DddImporter().importDriverCard(json)
        assertEquals(DddImporter.WEEKLY_DRIVE_LIMIT_SECONDS, summary.remainingWeeklyDriveSeconds, 0.01)
    }
}
