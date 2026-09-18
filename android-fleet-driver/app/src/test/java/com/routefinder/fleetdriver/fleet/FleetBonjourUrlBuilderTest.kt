package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FleetBonjourUrlBuilderTest {
    @Test
    fun httpWhenTlsFalse() {
        assertEquals(
            "http://192.168.1.10:8080",
            FleetBonjourDiscovery.baseUrl("192.168.1.10", 8080, usesTls = false),
        )
    }

    @Test
    fun httpsWhenTlsTrue() {
        assertEquals(
            "https://192.168.1.10:8443",
            FleetBonjourDiscovery.baseUrl("192.168.1.10", 8443, usesTls = true),
        )
    }

    @Test
    fun bracketsIpv6() {
        assertEquals(
            "http://[fe80::1]:8080",
            FleetBonjourDiscovery.baseUrl("fe80::1", 8080, usesTls = false),
        )
        assertEquals(
            "http://[fe80::1]:8080",
            FleetBonjourDiscovery.baseUrl("[fe80::1]", 8080, usesTls = false),
        )
    }

    @Test
    fun rejectsInvalidPort() {
        assertNull(FleetBonjourDiscovery.baseUrl("localhost", 0, usesTls = false))
        assertNull(FleetBonjourDiscovery.baseUrl("localhost", 70_000, usesTls = false))
        assertNull(FleetBonjourDiscovery.baseUrl("  ", 8080, usesTls = false))
    }

    @Test
    fun usesTlsFromTxt() {
        assertTrue(FleetBonjourDiscovery.usesTls(mapOf("tls" to "1".toByteArray())))
        assertFalse(FleetBonjourDiscovery.usesTls(mapOf("tls" to "0".toByteArray())))
        assertFalse(FleetBonjourDiscovery.usesTls(null))
        assertFalse(FleetBonjourDiscovery.usesTls(emptyMap()))
    }
}
