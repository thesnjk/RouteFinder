package com.routefinder.fleetdriver.fleet

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FleetProxyStatusLabelsTest {
    @Test
    fun maskApiKeyMatchesWebRules() {
        assertEquals("(none)", FleetProxyStatusLabels.maskApiKey(""))
        assertEquals("(none)", FleetProxyStatusLabels.maskApiKey("  "))
        assertEquals("••••", FleetProxyStatusLabels.maskApiKey("abcdef"))
        assertEquals("test…lpha", FleetProxyStatusLabels.maskApiKey("test-token-alpha"))
        assertEquals("Token: test…lpha", FleetProxyStatusLabels.maskedTokenLine("test-token-alpha"))
    }

    @Test
    fun authenticatedDepotLineUsesOrgIdentity() {
        val withId = JSONObject(
            """{"orgId":"11111111-1111-1111-1111-111111111111","orgName":"Demo Haulage Ltd"}""",
        )
        assertEquals(
            "Authenticated depot: Demo Haulage Ltd (11111111-1111-1111-1111-111111111111)",
            FleetProxyStatusLabels.authenticatedDepotLine(withId),
        )
        assertNull(FleetProxyStatusLabels.authenticatedDepotLine(JSONObject("{}")))
    }

    @Test
    fun orsSummaryAndNearCapMatchWebParity() {
        val ok = JSONObject(
            """
            {
              "orsConfigured": true,
              "routesToday": 12,
              "routeDailyCap": 2000,
              "geocodeToday": 40,
              "geocodeDailyCap": 500
            }
            """.trimIndent(),
        )
        assertEquals(1988, FleetProxyStatusLabels.routesRemaining(ok))
        assertEquals(460, FleetProxyStatusLabels.geocodesRemaining(ok))
        assertEquals(
            "ORS proxy: on · 12/2000 routes · 1988 left · 40/500 geocodes · 460 left",
            FleetProxyStatusLabels.orsSummaryLine(ok),
        )
        assertNull(FleetProxyStatusLabels.nearCapWarning(ok))

        val near = JSONObject(
            """
            {
              "orsConfigured": true,
              "routesToday": 900,
              "routeDailyCap": 1000,
              "geocodeToday": 10,
              "geocodeDailyCap": 500
            }
            """.trimIndent(),
        )
        assertTrue(FleetProxyStatusLabels.nearCapWarning(near)!!.contains("Near daily proxy cap"))

        val off = JSONObject("""{"orsConfigured":false,"routesToday":0,"routeDailyCap":100,"geocodeToday":0,"geocodeDailyCap":50}""")
        assertTrue(FleetProxyStatusLabels.orsSummaryLine(off).contains("off"))
    }
}
