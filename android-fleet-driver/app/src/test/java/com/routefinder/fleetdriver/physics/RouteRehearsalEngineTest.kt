package com.routefinder.fleetdriver.physics

import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteRehearsalEngineTest {
    @Test
    fun climbSlowsVsFlat() {
        // Short segments so elevation delta produces grade > 2%; webEta=0 compares pure kinetic.
        val flat = listOf(
            LatLon(52.0, 0.0, elevationMeters = 10.0),
            LatLon(52.0005, 0.0, elevationMeters = 10.0),
        )
        val climb = listOf(
            LatLon(52.0, 0.0, elevationMeters = 10.0),
            LatLon(52.0005, 0.0, elevationMeters = 80.0),
        )
        val flatEta = RouteRehearsalEngine.rehearse(flat, webEtaSeconds = 0.0)
        val climbEta = RouteRehearsalEngine.rehearse(climb, webEtaSeconds = 0.0)
        assertTrue("climb=$climbEta flat=$flatEta", climbEta > flatEta)
    }

    @Test
    fun gradeSpeedCaps() {
        assertTrue(RouteRehearsalEngine.gradeSpeedMps(0.1) < VehiclePhysicsDefaults.CRUISE_MPS)
        assertTrue(RouteRehearsalEngine.gradeSpeedMps(-0.1) >= VehiclePhysicsDefaults.CRUISE_MPS)
    }
}
