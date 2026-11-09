package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DvlaVehicleEnquiryClientTest {
    @Test
    fun parsesHgvRevenueWeightAndDefaults() {
        val json = """
            {
              "registrationNumber": "AB12CDE",
              "make": "DAF",
              "revenueWeight": 44000,
              "typeApproval": "N3",
              "wheelplan": "ARTICULATED",
              "fuelType": "DIESEL"
            }
        """.trimIndent()
        val spec = DvlaVehicleEnquiryClient.parseBody(json)
        assertNotNull(spec)
        assertEquals(44.0, spec!!.weightTonnes!!, 0.001)
        assertTrue(spec.isHeavyGoodsVehicle)
        assertEquals(4.0, spec.heightMeters!!, 0.001)
        assertEquals(2.55, spec.widthMeters!!, 0.001)
        assertEquals(16.5, spec.lengthMeters!!, 0.001)
        assertEquals("DAF", spec.make)
    }

    @Test
    fun lightVehicleWithoutHgvTags() {
        val json = """
            {
              "registrationNumber": "AB12CDE",
              "make": "FORD",
              "revenueWeight": 1640,
              "typeApproval": "M1",
              "fuelType": "PETROL"
            }
        """.trimIndent()
        val spec = DvlaVehicleEnquiryClient.parseBody(json)
        assertNotNull(spec)
        assertFalse(spec!!.isHeavyGoodsVehicle)
        assertEquals(1.64, spec.weightTonnes!!, 0.001)
        assertNull(spec.heightMeters)
    }

    @Test
    fun hgvHeuristicFromWheelplanWithoutWeight() {
        assertTrue(
            DvlaVehicleEnquiryClient.isHeavyGoodsVehicle(
                revenueWeightKg = null,
                typeApproval = null,
                wheelplan = "ARTICULATED",
                artics = null,
                fuelType = null,
            ),
        )
    }

    @Test
    fun emptyApiKeyLookupReturnsNull() {
        assertNull(DvlaVehicleEnquiryClient(apiKey = "  ").lookup("AB12CDE"))
    }

    @Test
    fun normalizeRegistrationStripsSpaces() {
        assertEquals("AB12CDE", DvlaVehicleEnquiryClient.normalizeRegistration("ab 12 cde"))
    }
}

class VehicleRegistrationResolverTest {
    @Test
    fun prefersRegCheckWhenDimsPresent() {
        val result = VehicleRegistrationResolver.resolve(
            registration = "AB12CDE",
            regCheckUsername = "user",
            dvlaApiKey = "dvla-key",
            regCheckLookup = {
                RegCheckClient.Spec(
                    heightMeters = 4.0,
                    weightTonnes = 40.0,
                    widthMeters = 2.55,
                    lengthMeters = 16.5,
                )
            },
            dvlaLookup = {
                DvlaVehicleEnquiryClient.Spec(
                    make = "DAF",
                    weightTonnes = 44.0,
                    isHeavyGoodsVehicle = true,
                    heightMeters = 4.0,
                    widthMeters = 2.55,
                    lengthMeters = 16.5,
                )
            },
        )
        assertEquals(VehicleRegistrationResolver.Source.REG_CHECK, result!!.source)
        assertEquals(40.0, result.weightTonnes!!, 0.001)
    }

    @Test
    fun fallsBackToDvlaWhenRegCheckMisses() {
        val result = VehicleRegistrationResolver.resolve(
            registration = "AB12CDE",
            regCheckUsername = "user",
            dvlaApiKey = "dvla-key",
            regCheckLookup = { null },
            dvlaLookup = {
                DvlaVehicleEnquiryClient.Spec(
                    make = "SCANIA",
                    weightTonnes = 44.0,
                    isHeavyGoodsVehicle = true,
                    heightMeters = 4.0,
                    widthMeters = 2.55,
                    lengthMeters = 16.5,
                )
            },
        )
        assertEquals(VehicleRegistrationResolver.Source.DVLA, result!!.source)
        assertEquals(44.0, result.weightTonnes!!, 0.001)
        assertEquals(4.0, result.heightMeters!!, 0.001)
    }

    @Test
    fun dvlaOnlyWhenRegCheckUnset() {
        val result = VehicleRegistrationResolver.resolve(
            registration = "AB12CDE",
            regCheckUsername = "",
            dvlaApiKey = "dvla-key",
            regCheckLookup = { error("should not call RegCheck") },
            dvlaLookup = {
                DvlaVehicleEnquiryClient.Spec(
                    make = "VOLVO",
                    weightTonnes = 32.0,
                    isHeavyGoodsVehicle = true,
                    heightMeters = 4.0,
                    widthMeters = 2.55,
                    lengthMeters = 16.5,
                )
            },
        )
        assertEquals(VehicleRegistrationResolver.Source.DVLA, result!!.source)
    }

    @Test
    fun returnsNullWhenBothMiss() {
        assertNull(
            VehicleRegistrationResolver.resolve(
                registration = "AB12CDE",
                regCheckUsername = "user",
                dvlaApiKey = "dvla-key",
                regCheckLookup = { null },
                dvlaLookup = { null },
            ),
        )
    }
}
