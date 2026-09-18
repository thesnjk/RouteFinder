package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VehicleQRParserTest {
    private val sample = "550e8400-e29b-41d4-a716-446655440000"

    @Test
    fun parsesBareUuid() {
        assertEquals(sample, VehicleQRParser.parse(sample))
        assertEquals(sample, VehicleQRParser.parse("  $sample  "))
    }

    @Test
    fun parsesPrefixedPayload() {
        assertEquals(sample, VehicleQRParser.parse("routefinder-vehicle:$sample"))
        assertEquals(sample, VehicleQRParser.parse("ROUTEFINDER-VEHICLE:$sample"))
        assertEquals(sample, VehicleQRParser.parse("routefinder-vehicle: $sample "))
    }

    @Test
    fun rejectsInvalid() {
        assertNull(VehicleQRParser.parse(""))
        assertNull(VehicleQRParser.parse("not-a-uuid"))
        assertNull(VehicleQRParser.parse("routefinder-vehicle:abc"))
        assertNull(VehicleQRParser.parse("550e8400-e29b-41d4-a716"))
    }
}
