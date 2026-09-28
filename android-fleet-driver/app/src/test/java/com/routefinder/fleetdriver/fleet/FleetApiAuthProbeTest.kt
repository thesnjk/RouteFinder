package com.routefinder.fleetdriver.fleet

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class FleetApiAuthProbeTest {
    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun healthAloneIsNotEnoughWhenProxyStatusRequiresKey() {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""{"ok":true,"version":"1"}"""),
        )
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"error":"Unauthorized"}"""),
        )

        val api = FleetApi(server.url("/").toString().trimEnd('/'), apiKey = "")
        assertTrue(api.health().optBoolean("ok"))
        try {
            api.verifyAuthenticatedAccess()
            fail("Expected auth probe to fail without API key")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("Fleet API key rejected") || e.message!!.contains("401"))
        }
        assertFalse(FleetConnectionGate.isConnected(healthOk = true, authSucceeded = false))
        assertTrue(
            FleetConnectionGate.statusLabel(
                healthOk = true,
                authSucceeded = false,
                authErrorMessage = "Fleet 401: Fleet API key rejected. Check the shared key with the operator.",
            ).startsWith("Auth failed"),
        )
    }

    @Test
    fun wrongApiKeyFailsAuthProbe() {
        server.enqueue(
            MockResponse()
                .setResponseCode(401)
                .setBody("""{"error":"Unauthorized"}"""),
        )

        val api = FleetApi(server.url("/").toString().trimEnd('/'), apiKey = "wrong-key")
        try {
            api.verifyAuthenticatedAccess()
            fail("Expected auth probe to fail with wrong API key")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("401") || e.message!!.contains("Fleet API key rejected"))
        }
    }

    @Test
    fun correctApiKeyPassesHealthAndAuthProbe() {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""{"ok":true,"version":"1"}"""),
        )
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""{"orsConfigured":true,"routesToday":0,"routeDailyCap":200}"""),
        )

        val api = FleetApi(server.url("/").toString().trimEnd('/'), apiKey = "fleet-secret")
        assertTrue(api.health().optBoolean("ok"))
        api.verifyAuthenticatedAccess()
        assertTrue(FleetConnectionGate.isConnected(healthOk = true, authSucceeded = true))
        assertEquals(
            "Connected",
            FleetConnectionGate.statusLabel(healthOk = true, authSucceeded = true),
        )

        val authRequest = server.takeRequest()
        assertTrue(authRequest.path!!.endsWith("/health") || authRequest.path == "/health")
        val probeRequest = server.takeRequest()
        assertTrue(probeRequest.path!!.contains("/v1/proxy/status"))
        assertTrue(probeRequest.getHeader("Authorization") == "Bearer fleet-secret")
    }

    @Test
    fun navAndHomeBadgeUseSameConnectedRuleAsWizard() {
        assertFalse(FleetConnectionGate.isConnected(healthOk = true, authSucceeded = false))
        assertFalse(FleetConnectionGate.isConnected(healthOk = false, authSucceeded = true))
        assertTrue(FleetConnectionGate.isConnected(healthOk = true, authSucceeded = true))
        assertEquals("Offline", FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false))
        val authFailed = FleetConnectionGate.statusLabel(
            healthOk = true,
            authSucceeded = false,
            authErrorMessage = "Fleet 401: Fleet API key rejected. Check the shared key with the operator.",
        )
        assertTrue(authFailed.startsWith("Auth failed · "))
        assertFalse(authFailed.contains("Offline"))
        assertEquals(authFailed, FleetConnectionGate.badgeTitle(authFailed))
        assertEquals(
            "Connected",
            FleetConnectionGate.badgeTitle(
                FleetConnectionGate.statusLabel(healthOk = true, authSucceeded = true),
            ),
        )
        assertEquals(
            "Offline",
            FleetConnectionGate.badgeTitle(
                FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false),
            ),
        )
    }
}
