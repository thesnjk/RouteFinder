package com.routefinder.fleetdriver.routing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FleetProxyErrorMapperTest {
    @Test
    fun route429_mapsToOrsCapCopy() {
        val message = FleetProxyErrorMapper.userMessage(
            statusCode = 429,
            body = "Fleet ORS route daily cap reached.",
            kind = FleetProxyErrorMapper.Kind.ORS_ROUTE,
        )
        assertEquals(FleetProxyErrorMapper.ORS_ROUTE_CAP_MESSAGE, message)
    }

    @Test
    fun bodyDailyCapWithout429_mapsToCapCopy() {
        val message = FleetProxyErrorMapper.userMessage(
            statusCode = 503,
            body = "Fleet ORS route daily cap reached.",
            kind = FleetProxyErrorMapper.Kind.ORS_ROUTE,
        )
        assertEquals(FleetProxyErrorMapper.ORS_ROUTE_CAP_MESSAGE, message)
    }

    @Test
    fun geocode429_mapsToGeocodeCapCopy() {
        val message = FleetProxyErrorMapper.userMessage(
            statusCode = 429,
            body = "Fleet ORS geocode daily cap reached.",
            kind = FleetProxyErrorMapper.Kind.GEOCODE,
        )
        assertEquals(FleetProxyErrorMapper.GEOCODE_CAP_MESSAGE, message)
    }

    @Test
    fun server500_includesTruncatedBody() {
        val message = FleetProxyErrorMapper.userMessage(
            statusCode = 500,
            body = "upstream timeout from ORS",
            kind = FleetProxyErrorMapper.Kind.ORS_ROUTE,
        )
        assertEquals("ORS route 500: upstream timeout from ORS", message)
    }

    @Test
    fun unauthorizedEmptyBody_isActionable() {
        val message = FleetProxyErrorMapper.userMessage(
            statusCode = 401,
            body = "",
            kind = FleetProxyErrorMapper.Kind.ORS_ROUTE,
        )
        assertTrue(message.contains("401"))
        assertTrue(message.contains("API key"))
    }
}
