package com.routefinder.fleetdriver.routing

import com.routefinder.fleetdriver.fleet.FleetTrip
import com.routefinder.fleetdriver.fleet.FleetVehicleProfile
import com.routefinder.fleetdriver.fleet.parseVehicleProfile
import com.routefinder.fleetdriver.fleet.toHgvVehicleProfile
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VehicleProfileComboLengthTest {
    @Test
    fun ukArticPresetHasOneTrailer() {
        assertEquals(1, HgvVehicleProfile.ukArtic.trailerCount)
        assertTrue(HgvVehicleProfile.ukArtic.usesArticulatedTrailer)
        assertEquals(1, HgvVehicleProfile.ukArtic.resolvedTrailerCount)
    }

    @Test
    fun ukRigidPresetHasZeroTrailers() {
        assertEquals(0, HgvVehicleProfile.ukRigid.trailerCount)
        assertFalse(HgvVehicleProfile.ukRigid.usesArticulatedTrailer)
    }

    @Test
    fun explicitZeroTrailersForcesRigidDespiteLongLength() {
        val profile = HgvVehicleProfile(lengthMeters = 16.5, trailerCount = 0)
        assertFalse(profile.usesArticulatedTrailer)
    }

    @Test
    fun legacyNilTrailerCountFallsBackToLength() {
        val long = HgvVehicleProfile(lengthMeters = 16.5, trailerCount = null)
        val short = HgvVehicleProfile(lengthMeters = 5.0, trailerCount = null)
        assertTrue(long.usesArticulatedTrailer)
        assertFalse(short.usesArticulatedTrailer)
    }

    @Test
    fun trailerCountClampsToThree() {
        assertEquals(3, HgvVehicleProfile.clampedTrailerCount(99))
        assertEquals(0, HgvVehicleProfile.clampedTrailerCount(0))
        assertNull(HgvVehicleProfile.clampedTrailerCount(null))
        val parsed = parseVehicleProfile(JSONObject("""{"trailerCount":99}"""))!!
        assertEquals(3, parsed.trailerCount)
    }

    @Test
    fun parseVehicleProfilePreservesTrailerCount() {
        val json = JSONObject(
            """{"height":4,"weight":44,"width":2.55,"length":16.5,"trailerCount":1}""",
        )
        val profile = parseVehicleProfile(json)!!
        assertEquals(1, profile.trailerCount)
        assertEquals(16.5, profile.length!!, 0.01)
    }

    @Test
    fun parseVehicleProfileMissingTrailerCountIsNull() {
        val json = JSONObject(
            """{"height":4,"weight":44,"width":2.55,"length":16.5}""",
        )
        val profile = parseVehicleProfile(json)!!
        assertNull(profile.trailerCount)
        val hgv = FleetTrip(
            id = "t1",
            orgId = "o1",
            vehicleId = "v1",
            status = "active",
            stops = emptyList(),
            physicsETASeconds = null,
            updatedAt = "2026-01-01T00:00:00Z",
            vehicleProfile = profile,
        ).toHgvVehicleProfile()
        assertNull(hgv.trailerCount)
        assertTrue(hgv.usesArticulatedTrailer)
    }

    @Test
    fun orsRequestStillSendsOverallLength() {
        val body = OrsDirectionsRequest.buildJson(
            originLon = -1.0,
            originLat = 52.0,
            destinationLon = -0.5,
            destinationLat = 52.5,
            vehicle = HgvVehicleProfile.ukRigid,
        )
        val restrictions = body
            .getJSONObject("options")
            .getJSONObject("profile_params")
            .getJSONObject("restrictions")
        assertEquals(12.0, restrictions.getDouble("length"), 0.01)
    }
}
