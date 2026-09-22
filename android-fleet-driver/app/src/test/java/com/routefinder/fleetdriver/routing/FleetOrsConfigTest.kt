package com.routefinder.fleetdriver.routing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FleetOrsConfigTest {
    @Test
    fun peliasAndOrsUrls() {
        val base = "http://192.168.1.10:8080"
        assertEquals(
            "http://192.168.1.10:8080/v1/proxy/pelias/v1",
            FleetOrsConfig.peliasBaseUrl(base),
        )
        assertEquals(
            "http://192.168.1.10:8080/v1/proxy/ors/v2",
            FleetOrsConfig.orsBaseUrl(base),
        )
        assertEquals(
            "http://192.168.1.10:8080/v1/proxy/ors/v2/directions/driving-hgv/geojson",
            FleetOrsConfig.hgvDirectionsUrl(base),
        )
    }

    @Test
    fun authKeyDefaults() {
        assertEquals("fleet-proxy", FleetOrsConfig.fleetProxyAuthKey(null))
        assertEquals("fleet-proxy", FleetOrsConfig.fleetProxyAuthKey("  "))
        assertEquals("secret", FleetOrsConfig.fleetProxyAuthKey("secret"))
    }

    @Test
    fun usesFleetProxy() {
        assertTrue(FleetOrsConfig.usesFleetProxy("http://10.0.2.2:8080"))
        assertFalse(FleetOrsConfig.usesFleetProxy(null))
        assertFalse(FleetOrsConfig.usesFleetProxy(""))
    }

    @Test
    fun httpsHostedBaseUrls() {
        val base = "https://fleet.example.com"
        assertEquals(
            "https://fleet.example.com/v1/proxy/pelias/v1",
            FleetOrsConfig.peliasBaseUrl(base),
        )
        assertEquals(
            "https://fleet.example.com/v1/proxy/ors/v2",
            FleetOrsConfig.orsBaseUrl(base),
        )
        assertEquals(
            "https://fleet.example.com/v1/proxy/ors/v2/directions/driving-hgv/geojson",
            FleetOrsConfig.hgvDirectionsUrl(base),
        )
        assertTrue(FleetOrsConfig.usesFleetProxy(base))
    }
}
