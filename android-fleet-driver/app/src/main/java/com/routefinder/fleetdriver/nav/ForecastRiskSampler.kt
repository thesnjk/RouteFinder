package com.routefinder.fleetdriver.nav

import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.LatLon
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt
import org.json.JSONObject

/**
 * Samples TomTom flow + OpenWeather forecast along the route for 1–3h horizon advisories.
 * Pure mapping helpers are unit-testable without network.
 */
object ForecastRiskSampler {
    val HORIZON_OFFSETS_METERS = listOf(60_000.0, 120_000.0, 180_000.0)
    const val REFRESH_INTERVAL_MS = 15 * 60 * 1000L

    fun shouldRefresh(lastRefreshMs: Long?, nowMs: Long = System.currentTimeMillis()): Boolean {
        if (lastRefreshMs == null) return true
        return nowMs - lastRefreshMs >= REFRESH_INTERVAL_MS
    }

    fun trafficAdvisory(
        currentSpeedKmh: Double,
        freeFlowSpeedKmh: Double,
        roadClosed: Boolean,
        arcLengthMeters: Double,
        currentArcLengthMeters: Double,
    ): PredictiveRiskEngine.Advisory? {
        val remaining = max(0.0, arcLengthMeters - currentArcLengthMeters)
        if (remaining <= 0) return null
        val ratio = if (freeFlowSpeedKmh > 0) currentSpeedKmh / freeFlowSpeedKmh else 1.0
        if (!roadClosed && ratio >= 0.45) return null
        val hoursAhead = max(1, (remaining / 60_000.0).toInt())
        val severity = if (roadClosed || ratio < 0.25) {
            PredictiveRiskEngine.Severity.SEVERE
        } else {
            PredictiveRiskEngine.Severity.CAUTION
        }
        val message = if (roadClosed) {
            "Forecast: closure risk ~${hoursAhead}h ahead on route"
        } else {
            "Forecast: heavy traffic bottleneck ~${hoursAhead}h ahead"
        }
        return PredictiveRiskEngine.Advisory(
            id = "forecast-traffic-${arcLengthMeters.toInt()}",
            kind = PredictiveRiskEngine.Kind.TRAFFIC,
            severity = severity,
            distanceRemainingMeters = remaining,
            message = message,
            source = "forecastTomTom",
        )
    }

    fun weatherAdvisory(
        conditionMain: String,
        windGustMps: Double?,
        visibilityMeters: Double?,
        arcLengthMeters: Double,
        currentArcLengthMeters: Double,
    ): PredictiveRiskEngine.Advisory? {
        val remaining = max(0.0, arcLengthMeters - currentArcLengthMeters)
        if (remaining <= 0) return null
        val main = conditionMain.lowercase()
        val parts = mutableListOf<String>()
        var severity = PredictiveRiskEngine.Severity.INFO
        if (main.contains("thunder") || main.contains("snow") || main.contains("ice")) {
            parts += conditionMain
            severity = PredictiveRiskEngine.Severity.SEVERE
        } else if (main.contains("rain") || main.contains("drizzle") || main.contains("storm")) {
            parts += conditionMain
            severity = PredictiveRiskEngine.Severity.CAUTION
        }
        if (windGustMps != null && windGustMps >= 18) {
            parts += "gusts ${windGustMps.toInt()} m/s"
            if (severity.ordinal < PredictiveRiskEngine.Severity.CAUTION.ordinal) {
                severity = PredictiveRiskEngine.Severity.CAUTION
            }
        }
        if (visibilityMeters != null && visibilityMeters > 0 && visibilityMeters < 1_000) {
            parts += "visibility under 1 km"
            if (severity.ordinal < PredictiveRiskEngine.Severity.CAUTION.ordinal) {
                severity = PredictiveRiskEngine.Severity.CAUTION
            }
        }
        if (parts.isEmpty()) return null
        val hoursAhead = max(1, (remaining / 60_000.0).toInt())
        val message = "Forecast weather ~${hoursAhead}h ahead: ${parts.joinToString(", ")}"
        return PredictiveRiskEngine.Advisory(
            id = "forecast-weather-${arcLengthMeters.toInt()}-${main.hashCode()}",
            kind = PredictiveRiskEngine.Kind.WEATHER,
            severity = severity,
            distanceRemainingMeters = remaining,
            message = message,
            source = "forecastOpenWeather",
        )
    }

    fun samplePointsAhead(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        offsetsMeters: List<Double> = HORIZON_OFFSETS_METERS,
    ): List<Pair<LatLon, Double>> {
        if (route.size < 2) return emptyList()
        val cumulative = cumulativeArcLengths(route)
        val total = cumulative.lastOrNull() ?: return emptyList()
        return offsetsMeters.mapNotNull { offset ->
            val target = currentArcLengthMeters + offset
            if (target <= currentArcLengthMeters || target > total) return@mapNotNull null
            pointAtArcLength(route, cumulative, target)?.let { it to target }
        }
    }

    fun sampleHorizon(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        tomTomApiKey: String?,
        openWeatherApiKey: String?,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
        tomTomProxyConfigured: Boolean = false,
        openWeatherProxyConfigured: Boolean = false,
    ): List<PredictiveRiskEngine.Advisory> {
        val items = mutableListOf<PredictiveRiskEngine.Advisory>()
        val fleet = fleetBaseUrl?.trim().orEmpty()
        val useTomTomProxy = fleet.isNotEmpty() && tomTomProxyConfigured
        val useOpenWeatherProxy = fleet.isNotEmpty() && openWeatherProxyConfigured
        val tomTom = tomTomApiKey?.trim().orEmpty()
        if (useTomTomProxy || tomTom.isNotEmpty()) {
            items += sampleTomTomHorizon(
                route = route,
                currentArcLengthMeters = currentArcLengthMeters,
                apiKey = tomTom,
                fleetBaseUrl = if (useTomTomProxy) fleet else null,
                fleetApiKey = fleetApiKey,
            )
        }
        val openWeather = openWeatherApiKey?.trim().orEmpty()
        if (useOpenWeatherProxy || openWeather.isNotEmpty()) {
            items += sampleOpenWeatherHorizon(
                route = route,
                currentArcLengthMeters = currentArcLengthMeters,
                apiKey = openWeather,
                fleetBaseUrl = if (useOpenWeatherProxy) fleet else null,
                fleetApiKey = fleetApiKey,
            )
        }
        return items
    }

    fun sampleTomTomHorizon(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        apiKey: String,
        offsetsMeters: List<Double> = HORIZON_OFFSETS_METERS,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<PredictiveRiskEngine.Advisory> {
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.TOMTOM_FLOW)) {
            return emptyList()
        }
        val points = samplePointsAhead(route, currentArcLengthMeters, offsetsMeters)
        val items = mutableListOf<PredictiveRiskEngine.Advisory>()
        for ((coord, arc) in points) {
            val flow = fetchTomTomFlow(coord, apiKey, fleetBaseUrl, fleetApiKey) ?: continue
            trafficAdvisory(
                currentSpeedKmh = flow.first,
                freeFlowSpeedKmh = flow.second,
                roadClosed = flow.third,
                arcLengthMeters = arc,
                currentArcLengthMeters = currentArcLengthMeters,
            )?.let { items += it }
        }
        if (points.isNotEmpty()) {
            ApiUsageLedger.record(ApiUsageLedger.Provider.TOMTOM_FLOW)
        }
        return items
    }

    fun sampleOpenWeatherHorizon(
        route: List<LatLon>,
        currentArcLengthMeters: Double,
        apiKey: String,
        offsetsMeters: List<Double> = HORIZON_OFFSETS_METERS,
        fleetBaseUrl: String? = null,
        fleetApiKey: String? = null,
    ): List<PredictiveRiskEngine.Advisory> {
        if (!ApiUsageLedger.allowsNonCriticalRequest(ApiUsageLedger.Provider.OPEN_WEATHER)) {
            return emptyList()
        }
        val points = samplePointsAhead(route, currentArcLengthMeters, offsetsMeters)
        val sample = points.firstOrNull() ?: return emptyList()
        val body = if (!fleetBaseUrl.isNullOrBlank()) {
            httpGet(
                FleetOrsConfig.openWeatherForecastUrl(fleetBaseUrl, sample.first.latitude, sample.first.longitude),
                authBearer = FleetOrsConfig.fleetProxyAuthKey(fleetApiKey),
            )
        } else {
            httpGet(
                "https://api.openweathermap.org/data/2.5/forecast" +
                    "?lat=${sample.first.latitude}&lon=${sample.first.longitude}" +
                    "&appid=${URLEncoder.encode(apiKey, Charsets.UTF_8.name())}" +
                    "&units=metric&cnt=8",
            )
        } ?: return emptyList()
        ApiUsageLedger.record(ApiUsageLedger.Provider.OPEN_WEATHER)
        return try {
            val list = JSONObject(body).optJSONArray("list") ?: return emptyList()
            buildList {
                for (i in 0 until minOf(3, list.length())) {
                    val entry = list.getJSONObject(i)
                    val weatherArr = entry.optJSONArray("weather")
                    val main = weatherArr?.optJSONObject(0)?.optString("main").orEmpty()
                    val gust = entry.optJSONObject("wind")?.let {
                        if (it.has("gust")) it.optDouble("gust") else null
                    }
                    val visibility = if (entry.has("visibility")) entry.optDouble("visibility") else null
                    val offsetIndex = minOf(i, offsetsMeters.lastIndex)
                    val arc = currentArcLengthMeters + offsetsMeters[offsetIndex]
                    weatherAdvisory(
                        conditionMain = main,
                        windGustMps = gust,
                        visibilityMeters = visibility,
                        arcLengthMeters = arc,
                        currentArcLengthMeters = currentArcLengthMeters,
                    )?.let { add(it) }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun fetchTomTomFlow(
        coord: LatLon,
        apiKey: String,
        fleetBaseUrl: String?,
        fleetApiKey: String?,
    ): Triple<Double, Double, Boolean>? {
        val url = if (!fleetBaseUrl.isNullOrBlank()) {
            FleetOrsConfig.tomTomFlowUrl(fleetBaseUrl, coord.latitude, coord.longitude)
        } else {
            "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json" +
                "?point=${coord.latitude},${coord.longitude}" +
                "&unit=KMPH&key=${URLEncoder.encode(apiKey, Charsets.UTF_8.name())}"
        }
        val body = httpGet(
            url,
            authBearer = if (!fleetBaseUrl.isNullOrBlank()) {
                FleetOrsConfig.fleetProxyAuthKey(fleetApiKey)
            } else {
                null
            },
        ) ?: return null
        return try {
            val data = JSONObject(body).getJSONObject("flowSegmentData")
            Triple(
                data.optDouble("currentSpeed"),
                data.optDouble("freeFlowSpeed"),
                data.optBoolean("roadClosure", false),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun httpGet(url: String, authBearer: String? = null): String? {
        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 8_000
                readTimeout = 8_000
                requestMethod = "GET"
                if (!authBearer.isNullOrBlank()) {
                    setRequestProperty("Authorization", "Bearer $authBearer")
                }
            }
            connection.inputStream.bufferedReader().use { it.readText() }
                .also { connection.disconnect() }
        } catch (_: Exception) {
            null
        }
    }

    private fun cumulativeArcLengths(route: List<LatLon>): List<Double> {
        val out = mutableListOf(0.0)
        var sum = 0.0
        for (i in 0 until route.lastIndex) {
            sum += haversineMeters(route[i], route[i + 1])
            out += sum
        }
        return out
    }

    private fun pointAtArcLength(
        route: List<LatLon>,
        cumulative: List<Double>,
        target: Double,
    ): LatLon? {
        for (i in 0 until route.lastIndex) {
            val a = cumulative[i]
            val b = cumulative[i + 1]
            if (target < a || target > b) continue
            val seg = b - a
            val t = if (seg > 0) (target - a) / seg else 0.0
            return LatLon(
                latitude = route[i].latitude + t * (route[i + 1].latitude - route[i].latitude),
                longitude = route[i].longitude + t * (route[i + 1].longitude - route[i].longitude),
            )
        }
        return route.lastOrNull()
    }

    private fun haversineMeters(a: LatLon, b: LatLon): Double {
        val earth = 6_371_000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * atan2(sqrt(h), sqrt(max(0.0, 1 - h)))
    }
}
