package com.routefinder.fleetdriver.nav

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.routefinder.fleetdriver.compliance.HosAdvisoryClock
import com.routefinder.fleetdriver.compliance.LaybyAdvisoryEngine
import com.routefinder.fleetdriver.compliance.LezAvoidPolicy
import com.routefinder.fleetdriver.compliance.UkLezCatalog
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.FleetSseClient
import com.routefinder.fleetdriver.fleet.FleetTrip
import com.routefinder.fleetdriver.fleet.FleetVehicleProfile
import com.routefinder.fleetdriver.fleet.JobIntakeHandler
import com.routefinder.fleetdriver.fleet.RegCheckClient
import com.routefinder.fleetdriver.fleet.SseConnectionState
import com.routefinder.fleetdriver.fleet.formatTimeWindowLines
import com.routefinder.fleetdriver.fleet.needsRegistrationLookup
import com.routefinder.fleetdriver.fleet.toHgvVehicleProfile
import com.routefinder.fleetdriver.inspection.InspectionChecklistFactory
import com.routefinder.fleetdriver.inspection.InspectionChecklistItem
import com.routefinder.fleetdriver.inspection.InspectionReportPdfRenderer
import com.routefinder.fleetdriver.inspection.InspectionSummary
import com.routefinder.fleetdriver.physics.RouteRehearsalEngine
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.FleetProxyStatusClient
import com.routefinder.fleetdriver.routing.GeocodeSuggestion
import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import com.routefinder.fleetdriver.routing.LatLon
import com.routefinder.fleetdriver.routing.OrsRoutingClient
import com.routefinder.fleetdriver.routing.PeliasGeocoder
import com.routefinder.fleetdriver.voice.VoiceGuidanceService
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class WaypointState(
    val label: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val isResolved: Boolean get() = latitude != null && longitude != null
}

/**
 * Orchestrates geocode, ORS HGV routing via fleet proxy, navigation, SSE trips, and rehearsal.
 */
class NavigationViewModel(application: Application) : AndroidViewModel(application) {
    val prefs = FleetPreferences(application)

    var origin by mutableStateOf(WaypointState())
    var destination by mutableStateOf(WaypointState())
    var originSuggestions by mutableStateOf<List<GeocodeSuggestion>>(emptyList())
    var destinationSuggestions by mutableStateOf<List<GeocodeSuggestion>>(emptyList())

    var isCalculating by mutableStateOf(false)
    var isRehearsing by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)
    var toastMessage by mutableStateOf<String?>(null)
    var connected by mutableStateOf(false)
    var orsConfigured by mutableStateOf(false)
    var tomTomProxyConfigured by mutableStateOf(false)
    var openWeatherProxyConfigured by mutableStateOf(false)
    var sseLabel by mutableStateOf("SSE idle")
    var statusLabel by mutableStateOf("Idle")

    val session = NavigationSession()
    var routeCoordinates by mutableStateOf<List<LatLon>>(emptyList())
    var phase by mutableStateOf(NavigationPhase.IDLE)
    var progress by mutableStateOf<NavigationProgress?>(null)
    var distanceLabel by mutableStateOf<String?>(null)
    var etaLabel by mutableStateOf<String?>(null)
    var physicsEtaLabel by mutableStateOf<String?>(null)

    var activeTrip by mutableStateOf<FleetTrip?>(null)
    var followLat by mutableStateOf<Double?>(null)
    var followLon by mutableStateOf<Double?>(null)
    /** Override dims from RegCheck when trip profile is empty. */
    private var intakeVehicleProfile by mutableStateOf<FleetVehicleProfile?>(null)
    var primaryRiskAdvisory by mutableStateOf<PredictiveRiskEngine.Advisory?>(null)
    /** Read-only dispatch time window lines for the status card. */
    var timeWindowLines by mutableStateOf<List<String>>(emptyList())
    var showWalkaround by mutableStateOf(false)
    var walkaroundItems by mutableStateOf(InspectionChecklistFactory.defaultItems())
    var lastInspectionSummary by mutableStateOf<InspectionSummary?>(null)
    private var lastKineticMessage: String? = null
    private var lastTrafficMessage: String? = null
    private var lastHazardMessage: String? = null
    private var lastHazardSevere: Boolean = false
    private var lastRoadworksMessage: String? = null
    private var lastWeatherMessage: String? = null
    private var cachedForecastItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var cachedClearanceItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var cachedOffRouteClearanceItems: List<PredictiveRiskEngine.Advisory> = emptyList()
    private var lastForecastRiskRefreshMs: Long? = null
    private var lastOffRouteClearanceMs: Long = 0L
    private var lastRiskRefreshMs: Long = 0L
    private var lastKnownBearingDegrees: Double? = null
    var regCheckUsernameDraft by mutableStateOf(prefs.regCheckUsername)
    var tomTomApiKeyDraft by mutableStateOf(prefs.tomTomApiKey)
    var openWeatherApiKeyDraft by mutableStateOf(prefs.openWeatherApiKey)
    var clearanceRadarEnabled by mutableStateOf(prefs.clearanceRadarEnabled)
    var lezAvoidEnabled by mutableStateOf(prefs.lezAvoidEnabled)
    var emissionClassDraft by mutableStateOf(prefs.emissionClass)
    var lezAdvisoryMessage by mutableStateOf<String?>(null)
    var laybyAdvisoryMessage by mutableStateOf<String?>(null)
    var hosAdvisoryMessage by mutableStateOf<String?>(null)
    var lastWalkaroundPdfBytes by mutableStateOf<ByteArray?>(null)
    private var continuousDriveSeconds = prefs.continuousDriveSeconds
    private var dailyDriveSeconds = prefs.dailyDriveSeconds
    private var lastDriveTickMs: Long = 0L

    private val voice = VoiceGuidanceService(application)
    private var sseJob: Job? = null
    private var healthJob: Job? = null
    private var gpsJob: Job? = null
    private var searchJob: Job? = null

    init {
        voice.enabled = prefs.voiceGuidanceEnabled
        if (prefs.isPaired()) {
            startFleetLoops()
        }
    }

    fun setVoiceEnabled(enabled: Boolean) {
        prefs.voiceGuidanceEnabled = enabled
        voice.enabled = enabled
    }

    fun updateRegCheckUsername(value: String) {
        regCheckUsernameDraft = value
        prefs.regCheckUsername = value
    }

    fun updateTomTomApiKey(value: String) {
        tomTomApiKeyDraft = value
        prefs.tomTomApiKey = value
    }

    fun updateOpenWeatherApiKey(value: String) {
        openWeatherApiKeyDraft = value
        prefs.openWeatherApiKey = value
    }

    fun updateClearanceRadarEnabled(enabled: Boolean) {
        clearanceRadarEnabled = enabled
        prefs.clearanceRadarEnabled = enabled
        if (!enabled) {
            cachedClearanceItems = emptyList()
            cachedOffRouteClearanceItems = emptyList()
            refreshPredictiveRisk()
        }
    }

    fun updateLezAvoidEnabled(enabled: Boolean) {
        lezAvoidEnabled = enabled
        prefs.lezAvoidEnabled = enabled
        refreshComplianceAdvisories()
    }

    fun updateEmissionClass(value: String) {
        emissionClassDraft = value
        prefs.emissionClass = value
        refreshComplianceAdvisories()
    }

    fun recordDrivingSeconds(deltaSeconds: Double) {
        continuousDriveSeconds += deltaSeconds
        dailyDriveSeconds += deltaSeconds
        prefs.continuousDriveSeconds = continuousDriveSeconds
        prefs.dailyDriveSeconds = dailyDriveSeconds
        refreshComplianceAdvisories()
    }

    fun resetHosBreak() {
        continuousDriveSeconds = 0.0
        prefs.continuousDriveSeconds = 0.0
        refreshComplianceAdvisories()
        toastMessage = "Break recorded — continuous clock reset"
    }

    fun startFleetLoops() {
        healthJob?.cancel()
        healthJob = viewModelScope.launch {
            while (isActive && prefs.isPaired()) {
                refreshHealth()
                delay(30_000)
            }
        }
        sseJob?.cancel()
        sseJob = viewModelScope.launch {
            if (!prefs.isPaired()) return@launch
            val api = FleetApi(prefs.baseUrl, prefs.apiKey)
            try {
                FleetSseClient(api).eventsWithReconnect(
                    vehicleId = prefs.vehicleId,
                    onState = { state ->
                        launch(Dispatchers.Main.immediate) {
                            sseLabel = when (state) {
                                is SseConnectionState.Listening -> "SSE listening"
                                is SseConnectionState.Reconnecting ->
                                    "Reconnecting in ${state.delaySeconds}s…"
                                is SseConnectionState.Stopped -> "SSE stopped"
                            }
                        }
                    },
                ).collect { event ->
                    statusLabel = "SSE ${event.kind}"
                    if (event.kind == "tripPushed" && event.tripId != null) {
                        val trip = withContext(Dispatchers.IO) { api.getTrip(event.tripId) }
                        applyFleetTrip(trip)
                    }
                }
            } catch (e: Exception) {
                errorMessage = e.message
                sseLabel = "SSE stopped"
            }
        }
    }

    suspend fun refreshHealth() {
        try {
            val health = withContext(Dispatchers.IO) {
                FleetApi(prefs.baseUrl, prefs.apiKey).health()
            }
            connected = health.optBoolean("ok")
            try {
                val proxy = withContext(Dispatchers.IO) {
                    FleetProxyStatusClient(prefs.baseUrl, prefs.apiKey).fetch()
                }
                orsConfigured = proxy.orsConfigured
                tomTomProxyConfigured = proxy.tomTomConfigured
                openWeatherProxyConfigured = proxy.openWeatherConfigured
            } catch (_: Exception) {
                orsConfigured = FleetOrsConfig.usesFleetProxy(prefs.baseUrl)
                tomTomProxyConfigured = false
                openWeatherProxyConfigured = false
            }
            statusLabel = if (connected) "Connected" else "Offline"
        } catch (e: Exception) {
            connected = false
            statusLabel = "Offline"
            errorMessage = e.message
        }
    }

    fun searchOrigin(query: String) = search(query, isOrigin = true)
    fun searchDestination(query: String) = search(query, isOrigin = false)

    private fun search(query: String, isOrigin: Boolean) {
        if (isOrigin) origin = origin.copy(label = query, latitude = null, longitude = null)
        else destination = destination.copy(label = query, latitude = null, longitude = null)
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(350)
            if (query.trim().length < 2) {
                if (isOrigin) originSuggestions = emptyList() else destinationSuggestions = emptyList()
                return@launch
            }
            try {
                val results = withContext(Dispatchers.IO) {
                    PeliasGeocoder(prefs.baseUrl, prefs.apiKey).search(query)
                }
                if (isOrigin) originSuggestions = results else destinationSuggestions = results
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }

    fun selectOrigin(suggestion: GeocodeSuggestion) {
        origin = WaypointState(suggestion.label, suggestion.latitude, suggestion.longitude)
        originSuggestions = emptyList()
    }

    fun selectDestination(suggestion: GeocodeSuggestion) {
        destination = WaypointState(suggestion.label, suggestion.latitude, suggestion.longitude)
        destinationSuggestions = emptyList()
    }

    fun findRoute() {
        viewModelScope.launch { findRouteInternal() }
    }

    private suspend fun findRouteInternal() {
        errorMessage = null
        val oLat = origin.latitude
        val oLon = origin.longitude
        val dLat = destination.latitude
        val dLon = destination.longitude
        if (oLat == null || oLon == null || dLat == null || dLon == null) {
            errorMessage = "Resolve origin and destination first"
            return
        }
        if (!FleetOrsConfig.usesFleetProxy(prefs.baseUrl)) {
            errorMessage = "Pair with fleet server (no driver ORS key required)"
            return
        }
        isCalculating = true
        try {
            val emission = runCatching {
                UkLezCatalog.EmissionClass.valueOf(emissionClassDraft.trim().uppercase())
            }.getOrNull()
            val avoidRings = LezAvoidPolicy.polygons(
                emissionClass = emission,
                avoidEnabled = lezAvoidEnabled,
                origin = LatLon(oLat, oLon),
                destination = LatLon(dLat, dLon),
            )
            val result = withContext(Dispatchers.IO) {
                OrsRoutingClient(prefs.baseUrl, prefs.apiKey).route(
                    originLon = oLon,
                    originLat = oLat,
                    destinationLon = dLon,
                    destinationLat = dLat,
                    vehicle = resolveHgvProfile(),
                    avoidPolygons = avoidRings,
                )
            }
            val geometry = RouteGeometry(
                coordinates = result.coordinates,
                totalLengthMeters = result.distanceMeters,
                staticEtaSeconds = result.durationSeconds,
            )
            session.loadRoute(geometry, result.instructions)
            routeCoordinates = result.coordinates
            phase = session.phase
            progress = session.progress
            distanceLabel = formatDistance(result.distanceMeters)
            etaLabel = formatDuration(result.durationSeconds)
            physicsEtaLabel = null
            voice.resetAnnouncements()
            statusLabel = "Route loaded"
            refreshComplianceAdvisories(result.coordinates)
            refreshClearanceAndForecastRisk(result.coordinates)
        } catch (e: Exception) {
            errorMessage = e.message
        } finally {
            isCalculating = false
        }
    }

    fun startNavigation() {
        session.startNavigation()
        phase = session.phase
        progress = session.progress
        voice.resetAnnouncements()
        statusLabel = "Navigating"
        startGpsLoop()
    }

    fun stopNavigation() {
        session.stopNavigation()
        phase = session.phase
        progress = null
        gpsJob?.cancel()
        statusLabel = "Route loaded"
    }

    fun rehearseRoute() {
        val geo = session.geometry ?: return
        viewModelScope.launch {
            isRehearsing = true
            try {
                val kinetic = withContext(Dispatchers.Default) {
                    RouteRehearsalEngine.rehearse(geo.coordinates, geo.staticEtaSeconds)
                }
                session.physicsEtaSeconds = kinetic
                physicsEtaLabel = formatDuration(kinetic)
                lastKineticMessage = "Physics ETA ${formatDuration(kinetic)} — review grades before depart"
                refreshPredictiveRisk()
                statusLabel = "Rehearsed"
                val trip = activeTrip
                if (trip != null) {
                    try {
                        withContext(Dispatchers.IO) {
                            FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                trip = trip,
                                status = trip.status,
                                physicsETASeconds = kinetic,
                            )
                        }
                        activeTrip = trip.copy(physicsETASeconds = kinetic)
                    } catch (e: Exception) {
                        errorMessage = e.message
                    }
                }
            } catch (e: Exception) {
                errorMessage = e.message
            } finally {
                isRehearsing = false
            }
        }
    }

    fun applyFleetTrip(trip: FleetTrip) {
        viewModelScope.launch {
            activeTrip = trip
            timeWindowLines = formatTimeWindowLines(trip)
            intakeVehicleProfile = trip.vehicleProfile
            toastMessage = "Trip received"
            val ordered = JobIntakeHandler.orderedStops(trip)
            val first = ordered.firstOrNull()
            val last = ordered.lastOrNull()
            if (first != null) {
                origin = WaypointState(first.label, first.latitude, first.longitude)
            }
            if (last != null) {
                destination = WaypointState(last.label, last.latitude, last.longitude)
            }
            if (needsRegistrationLookup(trip) && prefs.regCheckUsername.isNotBlank()) {
                try {
                    val plate = withContext(Dispatchers.IO) {
                        val api = FleetApi(prefs.baseUrl, prefs.apiKey)
                        api.vehiclesForOrg(trip.orgId)
                            .firstOrNull { it.id == trip.vehicleId }
                            ?.registrationPlate
                    }
                    if (!plate.isNullOrBlank()) {
                        val spec = withContext(Dispatchers.IO) {
                            RegCheckClient(prefs.regCheckUsername).lookup(plate)
                        }
                        if (spec != null) {
                            intakeVehicleProfile = FleetVehicleProfile(
                                height = spec.heightMeters ?: trip.vehicleProfile?.height,
                                weight = spec.weightTonnes ?: trip.vehicleProfile?.weight,
                                width = spec.widthMeters ?: trip.vehicleProfile?.width,
                                length = spec.lengthMeters ?: trip.vehicleProfile?.length,
                                axleWeight = trip.vehicleProfile?.axleWeight,
                            )
                            toastMessage = "RegCheck dims applied"
                        }
                    }
                } catch (_: Exception) {
                    // Never block intake on RegCheck failure.
                }
            }
            try {
                withContext(Dispatchers.IO) {
                    FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                        trip = trip,
                        status = "accepted",
                    )
                }
            } catch (_: Exception) {
            }
            if (JobIntakeHandler.shouldAutoFindRoute(trip) && origin.isResolved && destination.isResolved) {
                findRouteInternal()
                if (JobIntakeHandler.shouldAutoRehearse(trip) && routeCoordinates.isNotEmpty()) {
                    rehearseRoute()
                }
            }
            refreshPredictiveRisk()
        }
    }

    fun openWalkaround() {
        walkaroundItems = InspectionChecklistFactory.defaultItems()
        showWalkaround = true
    }

    fun updateWalkaroundItem(index: Int, item: InspectionChecklistItem) {
        walkaroundItems = walkaroundItems.toMutableList().also { it[index] = item }
    }

    fun completeWalkaround() {
        if (!InspectionChecklistFactory.allZonesReviewed(walkaroundItems)) {
            errorMessage = "Mark every walkaround item Pass or Defect"
            return
        }
        val trip = activeTrip
        val summary = InspectionChecklistFactory.summary(
            items = walkaroundItems,
            vehicleLabel = trip?.vehicleId?.take(8) ?: "Vehicle",
            registrationPlate = null,
        )
        lastInspectionSummary = summary
        lastWalkaroundPdfBytes = InspectionReportPdfRenderer.pdfBytes(summary, walkaroundItems)
        showWalkaround = false
        if (trip == null) {
            toastMessage = "Walkaround PDF saved locally (${summary.photoCount} photo(s))"
            return
        }
        viewModelScope.launch {
            try {
                val defects = JSONArray()
                walkaroundItems.filter { it.status.name == "DEFECT" }.forEach { item ->
                    defects.put(
                        JSONObject()
                            .put("zone", item.zone.label)
                            .put("label", item.label)
                            .put("note", item.note)
                            .put("hasPhoto", item.photoBase64 != null),
                    )
                }
                val payload = JSONObject()
                    .put("vehicleLabel", summary.vehicleLabel)
                    .put("registrationPlate", summary.registrationPlate ?: JSONObject.NULL)
                    .put("defectCount", summary.defectCount)
                    .put("photoCount", summary.photoCount)
                    .put("completedAt", summary.completedAt)
                    .put("defects", defects)
                withContext(Dispatchers.IO) {
                    FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                        trip = trip,
                        status = trip.status,
                        latestInspectionSummary = payload,
                    )
                }
                toastMessage = if (summary.defectCount > 0) {
                    "Walkaround: ${summary.defectCount} defect(s), ${summary.photoCount} photo(s) → dispatch + PDF"
                } else {
                    "Walkaround complete — PDF ready"
                }
            } catch (e: Exception) {
                errorMessage = e.message
            }
        }
    }

    private fun refreshComplianceAdvisories(route: List<LatLon> = routeCoordinates) {
        val emission = runCatching {
            UkLezCatalog.EmissionClass.valueOf(emissionClassDraft.trim().uppercase())
        }.getOrNull()
        lezAdvisoryMessage = UkLezCatalog.announcement(
            route = route,
            emissionClass = emission,
            avoidEnabled = lezAvoidEnabled,
        )
        laybyAdvisoryMessage = LaybyAdvisoryEngine.nearestAhead(route)
        hosAdvisoryMessage = HosAdvisoryClock.snapshot(
            continuousDriveSeconds = continuousDriveSeconds,
            dailyDriveSeconds = dailyDriveSeconds,
        ).message
    }

    fun dismissWalkaround() {
        showWalkaround = false
    }

    private fun resolveHgvProfile(): HgvVehicleProfile {
        val trip = activeTrip
        if (trip != null) {
            val merged = trip.copy(vehicleProfile = intakeVehicleProfile ?: trip.vehicleProfile)
            return merged.toHgvVehicleProfile()
        }
        return HgvVehicleProfile()
    }

    private fun refreshPredictiveRisk() {
        val trip = activeTrip
        val schedule = if (trip != null) {
            TimeWindowRiskEvaluator.advisory(
                windows = trip.jobBrief?.timeWindows.orEmpty(),
                stops = trip.stops,
                physicsEtaSeconds = trip.physicsETASeconds
                    ?: session.physicsEtaSeconds
                    ?: progress?.remainingEtaSeconds,
            )
        } else {
            null
        }
        val fused = PredictiveRiskEngine.fuse(
            PredictiveRiskEngine.Snapshot(
                kineticMessage = lastKineticMessage,
                kineticDistanceMeters = 1_500.0,
                weatherMessage = lastWeatherMessage,
                weatherDistanceMeters = if (lastWeatherMessage != null) 3_000.0 else null,
                hazardMessage = lastHazardMessage,
                hazardDistanceMeters = if (lastHazardMessage != null) 1_200.0 else null,
                hazardSevere = lastHazardSevere,
                roadworksMessage = lastRoadworksMessage,
                roadworksDistanceMeters = if (lastRoadworksMessage != null) 2_000.0 else null,
                trafficMessage = lastTrafficMessage,
                trafficDistanceMeters = if (lastTrafficMessage != null) 2_500.0 else null,
                scheduleLateMessage = schedule?.message,
                scheduleLateDistanceMeters = schedule?.distanceMeters,
                forecastItems = cachedForecastItems,
                clearanceItems = cachedClearanceItems + cachedOffRouteClearanceItems,
            ),
        )
        primaryRiskAdvisory = PredictiveRiskEngine.primaryAhead(fused)
    }

    private suspend fun refreshClearanceAndForecastRisk(route: List<LatLon>) {
        val profile = resolveHgvProfile()
        cachedClearanceItems = if (clearanceRadarEnabled && route.size >= 2) {
            withContext(Dispatchers.IO) {
                ClearanceCorridorProbe.advisoriesAlongRoute(
                    route = route,
                    profile = profile,
                    currentArcLengthMeters = 0.0,
                    fleetBaseUrl = prefs.baseUrl,
                    fleetApiKey = prefs.apiKey,
                )
            }
        } else {
            emptyList()
        }
        cachedOffRouteClearanceItems = emptyList()
        lastForecastRiskRefreshMs = null
        refreshForecastRiskIfNeeded(force = true, route = route)
        refreshPredictiveRisk()
    }

    private suspend fun refreshForecastRiskIfNeeded(
        force: Boolean = false,
        route: List<LatLon> = routeCoordinates,
    ) {
        if (route.size < 2) return
        if (!force && !ForecastRiskSampler.shouldRefresh(lastForecastRiskRefreshMs)) return
        val tomTom = prefs.tomTomApiKey.takeIf { it.isNotBlank() }
        val openWeather = prefs.openWeatherApiKey.takeIf { it.isNotBlank() }
        if (tomTom == null && openWeather == null && !tomTomProxyConfigured && !openWeatherProxyConfigured) {
            cachedForecastItems = emptyList()
            return
        }
        cachedForecastItems = withContext(Dispatchers.IO) {
            ForecastRiskSampler.sampleHorizon(
                route = route,
                currentArcLengthMeters = 0.0,
                tomTomApiKey = tomTom,
                openWeatherApiKey = openWeather,
                fleetBaseUrl = prefs.baseUrl,
                fleetApiKey = prefs.apiKey,
                tomTomProxyConfigured = tomTomProxyConfigured,
                openWeatherProxyConfigured = openWeatherProxyConfigured,
            )
        }
        lastForecastRiskRefreshMs = System.currentTimeMillis()
    }

    private suspend fun refreshOffRouteClearanceIfNeeded(lat: Double, lon: Double, bearing: Double?) {
        if (!clearanceRadarEnabled || routeCoordinates.size < 2) {
            if (cachedOffRouteClearanceItems.isNotEmpty()) {
                cachedOffRouteClearanceItems = emptyList()
                refreshPredictiveRisk()
            }
            return
        }
        val point = LatLon(lat, lon)
        val (offRoute, _) = ClearanceCorridorProbe.isOffRoute(point, routeCoordinates)
        if (!offRoute) {
            if (cachedOffRouteClearanceItems.isNotEmpty()) {
                cachedOffRouteClearanceItems = emptyList()
                refreshPredictiveRisk()
            }
            return
        }
        val heading = bearing ?: lastKnownBearingDegrees ?: return
        val now = System.currentTimeMillis()
        if (now - lastOffRouteClearanceMs < ClearanceCorridorProbe.OFF_ROUTE_REFRESH_INTERVAL_MS) {
            return
        }
        lastOffRouteClearanceMs = now
        val profile = resolveHgvProfile()
        val items = withContext(Dispatchers.IO) {
            ClearanceCorridorProbe.advisoriesAlongHeading(
                from = point,
                bearingDegrees = heading,
                profile = profile,
                force = true,
                fleetBaseUrl = prefs.baseUrl,
                fleetApiKey = prefs.apiKey,
            )
        }
        if (items.isNotEmpty() || cachedOffRouteClearanceItems.isEmpty()) {
            cachedOffRouteClearanceItems = items
            refreshPredictiveRisk()
        }
    }

    /**
     * Derives traffic / hazard risk strings from live nav progress (no TomTom key required).
     * Slow implied speed → traffic caution; crawl near a turn → hazard-style alert.
     */
    private fun updateRiskFromProgress(progress: NavigationProgress) {
        val remainingM = progress.remainingDistanceMeters
        val remainingEta = progress.remainingEtaSeconds
        val toManeuver = progress.distanceToNextManeuverMeters
        if (remainingM > 200 && remainingEta > 30) {
            val impliedKmh = (remainingM / remainingEta) * 3.6
            lastTrafficMessage = when {
                impliedKmh < 15 -> "Heavy traffic on remaining corridor (~${impliedKmh.toInt()} km/h)"
                impliedKmh < 35 -> "Slow traffic ahead on corridor (~${impliedKmh.toInt()} km/h)"
                else -> null
            }
        } else {
            lastTrafficMessage = null
        }
        // Near-maneuver crawl: treat as localized hazard when ETA for remaining route implies
        // the vehicle is barely moving while still approaching the turn.
        if (toManeuver in 80.0..1_500.0 && remainingM > 0 && remainingEta > 0) {
            val corridorKmh = (remainingM / remainingEta) * 3.6
            if (corridorKmh < 12) {
                lastHazardMessage = "Congestion near next turn — ${formatDistance(toManeuver)}"
                lastHazardSevere = corridorKmh < 6
            } else {
                lastHazardMessage = null
                lastHazardSevere = false
            }
        } else if (toManeuver < 80) {
            lastHazardMessage = null
            lastHazardSevere = false
        }
        refreshPredictiveRisk()
    }

    fun ingestLocation(lat: Double, lon: Double, bearingDegrees: Double? = null) {
        followLat = lat
        followLon = lon
        if (bearingDegrees != null) {
            lastKnownBearingDegrees = bearingDegrees
        }
        session.ingestPosition(lat, lon)
        phase = session.phase
        progress = session.progress
        session.currentInstruction()?.let { instruction ->
            val p = progress
            if (p != null) {
                voice.onProgress(instruction, p.currentManeuverIndex, p.distanceToNextManeuverMeters)
            }
        }
        progress?.let {
            distanceLabel = formatDistance(it.remainingDistanceMeters)
            etaLabel = formatDuration(it.remainingEtaSeconds)
            if (phase == NavigationPhase.NAVIGATING) {
                val now = System.currentTimeMillis()
                if (now - lastRiskRefreshMs >= 5_000L) {
                    lastRiskRefreshMs = now
                    if (lastDriveTickMs > 0) {
                        val delta = (now - lastDriveTickMs) / 1_000.0
                        if (delta > 0 && delta < 120) {
                            recordDrivingSeconds(delta)
                        }
                    }
                    lastDriveTickMs = now
                    updateRiskFromProgress(it)
                    viewModelScope.launch {
                        refreshForecastRiskIfNeeded()
                        refreshOffRouteClearanceIfNeeded(lat, lon, bearingDegrees ?: lastKnownBearingDegrees)
                        refreshPredictiveRisk()
                    }
                }
            }
        }
    }

    private fun startGpsLoop() {
        gpsJob?.cancel()
        gpsJob = viewModelScope.launch {
            // Location injection is performed by the UI with FusedLocation; this loop publishes snapshots.
            while (isActive && session.phase == NavigationPhase.NAVIGATING) {
                val trip = activeTrip
                val lat = followLat
                val lon = followLon
                if (trip != null && lat != null && lon != null) {
                    try {
                        withContext(Dispatchers.IO) {
                            FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                trip = trip,
                                status = trip.status,
                                driverLatitude = lat,
                                driverLongitude = lon,
                                driverLocationRecordedAt = Instant.now().toString(),
                            )
                        }
                    } catch (_: Exception) {
                    }
                }
                delay(20_000)
            }
        }
    }

    fun clearToast() {
        toastMessage = null
    }

    override fun onCleared() {
        sseJob?.cancel()
        healthJob?.cancel()
        gpsJob?.cancel()
        voice.shutdown()
        super.onCleared()
    }

    companion object {
        fun formatDistance(meters: Double): String =
            if (meters >= 1000) "%.1f km".format(meters / 1000.0) else "${meters.toInt()} m"

        fun formatDuration(seconds: Double): String {
            val minutes = (seconds / 60).toInt()
            return if (minutes < 60) "$minutes min" else "${minutes / 60}h ${minutes % 60}m"
        }
    }
}
