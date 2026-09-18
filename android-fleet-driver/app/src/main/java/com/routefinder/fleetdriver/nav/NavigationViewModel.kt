package com.routefinder.fleetdriver.nav

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.FleetSseClient
import com.routefinder.fleetdriver.fleet.FleetTrip
import com.routefinder.fleetdriver.fleet.SseConnectionState
import com.routefinder.fleetdriver.physics.RouteRehearsalEngine
import com.routefinder.fleetdriver.routing.FleetOrsConfig
import com.routefinder.fleetdriver.routing.FleetProxyStatusClient
import com.routefinder.fleetdriver.routing.GeocodeSuggestion
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
            } catch (_: Exception) {
                orsConfigured = FleetOrsConfig.usesFleetProxy(prefs.baseUrl)
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
            val result = withContext(Dispatchers.IO) {
                OrsRoutingClient(prefs.baseUrl, prefs.apiKey).route(
                    originLon = oLon,
                    originLat = oLat,
                    destinationLon = dLon,
                    destinationLat = dLat,
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
                statusLabel = "Rehearsed"
                activeTrip?.let { trip ->
                    withContext(Dispatchers.IO) {
                        FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                            trip = trip,
                            status = trip.status,
                            physicsETASeconds = kinetic,
                        )
                    }
                    activeTrip = trip.copy(physicsETASeconds = kinetic)
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
            toastMessage = "Trip received"
            val ordered = trip.stops.sortedBy { it.sequence }
            val first = ordered.firstOrNull()
            val last = ordered.lastOrNull()
            if (first != null) {
                origin = WaypointState(first.label, first.latitude, first.longitude)
            }
            if (last != null) {
                destination = WaypointState(last.label, last.latitude, last.longitude)
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
            if (origin.isResolved && destination.isResolved) {
                findRouteInternal()
            }
        }
    }

    fun ingestLocation(lat: Double, lon: Double) {
        followLat = lat
        followLon = lon
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
