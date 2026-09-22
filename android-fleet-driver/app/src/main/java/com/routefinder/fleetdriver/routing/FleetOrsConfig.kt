package com.routefinder.fleetdriver.routing

/**
 * Fleet ORS / Pelias proxy URL and auth helpers
 * (mirrors iOS FleetORSRoutingFactory).
 */
object FleetOrsConfig {
    const val DEFAULT_PROXY_AUTH = "fleet-proxy"
    const val USER_AGENT = "RouteFinder-Android-FleetDriver/0.2"

    fun fleetProxyAuthKey(apiKey: String?): String {
        val trimmed = apiKey?.trim().orEmpty()
        return if (trimmed.isNotEmpty()) trimmed else DEFAULT_PROXY_AUTH
    }

    fun usesFleetProxy(baseUrl: String?): Boolean =
        !baseUrl.isNullOrBlank()

    fun peliasBaseUrl(fleetServerBase: String): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/pelias/v1"
    }

    fun orsBaseUrl(fleetServerBase: String): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/ors/v2"
    }

    fun proxyStatusUrl(fleetServerBase: String): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/status"
    }

    fun tomTomFlowUrl(fleetServerBase: String, lat: Double, lon: Double): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/tomtom/flow?point=$lat,$lon"
    }

    fun openWeatherForecastUrl(fleetServerBase: String, lat: Double, lon: Double): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/openweather/forecast?lat=$lat&lon=$lon&cnt=8"
    }

    fun overpassInterpreterUrl(fleetServerBase: String): String {
        val base = fleetServerBase.trimEnd('/')
        return "$base/v1/proxy/overpass/interpreter"
    }

    fun hgvDirectionsUrl(fleetServerBase: String): String =
        "${orsBaseUrl(fleetServerBase)}/directions/driving-hgv/geojson"
}
