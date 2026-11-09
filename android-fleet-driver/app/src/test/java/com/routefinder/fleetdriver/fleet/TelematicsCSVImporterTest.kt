package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class TelematicsCSVImporterTest {
    @Test
    fun parsesGeotabStyleHeaders() {
        val csv = """
            Device,Latitude,Longitude,DateTime,Speed
            Artic 1,52.6309,1.2974,2026-09-15T10:00:00Z,64
            Artic 2,53.4808,-2.2426,2026-09-15T10:05:00Z,48
        """.trimIndent()
        val pings = TelematicsCSVImporter.parse(csv, TelematicsProvider.GEOTAB)
        assertEquals(2, pings.size)
        assertEquals("Artic 1", pings[0].vehicleLabel)
        assertEquals(52.6309, pings[0].latitude, 0.0001)
        assertEquals(TelematicsProvider.GEOTAB, pings[0].provider)
        assertEquals(48.0, pings[1].speedKph!!, 0.001)
    }

    @Test
    fun rejectsMissingColumns() {
        assertThrows(TelematicsCSVImporterError.MissingRequiredColumns::class.java) {
            TelematicsCSVImporter.parse("Name,Foo\nA,1\n")
        }
    }

    @Test
    fun rejectsEmptyFile() {
        assertThrows(TelematicsCSVImporterError.EmptyFile::class.java) {
            TelematicsCSVImporter.parse("   \n  ")
        }
    }

    @Test
    fun ingestVehicleIdIsStableForLabel() {
        val a = TelematicsVehiclePing(
            provider = TelematicsProvider.SAMSARA,
            vehicleLabel = "Unit 9",
            latitude = 51.5,
            longitude = -0.1,
            recordedAt = java.time.Instant.parse("2026-01-01T00:00:00Z"),
        )
        val b = TelematicsVehiclePing(
            provider = TelematicsProvider.SAMSARA,
            vehicleLabel = "Unit 9",
            latitude = 51.6,
            longitude = -0.2,
            recordedAt = java.time.Instant.parse("2026-01-01T01:00:00Z"),
        )
        assertEquals(a.ingestVehicleId(), b.ingestVehicleId())
        assertTrue(a.ingestVehicleId().toString().isNotBlank())
    }

    @Test
    fun parseBatchKeepsSourceFileName() {
        val batch = TelematicsCSVImporter.parseBatch(
            text = """
                vehicle,lat,lon
                Truck A,52.1,0.2
            """.trimIndent(),
            sourceFileName = "export.csv",
        )
        assertEquals(1, batch.pings.size)
        assertEquals("export.csv", batch.sourceFileName)
    }
}
