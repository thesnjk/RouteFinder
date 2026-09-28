package com.routefinder.fleetdriver.ui

import android.Manifest
import android.annotation.SuppressLint
import android.os.SystemClock
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetConnectionGate
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.FleetSseClient
import com.routefinder.fleetdriver.fleet.FleetTrip
import com.routefinder.fleetdriver.fleet.SseConnectionState
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Post-setup home: connection badge, trip card, SSE listen, accept + periodic GPS snapshot.
 */
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun DriverHomeScreen(
    prefs: FleetPreferences,
    onReconfigure: () -> Unit,
) {
    var status by remember { mutableStateOf("Idle") }
    var connected by remember { mutableStateOf(false) }
    var serverVersion by remember { mutableStateOf<String?>(null) }
    var lastHealthAt by remember { mutableStateOf<Instant?>(null) }
    var lastHealthLabel by remember { mutableStateOf<String?>(null) }
    var trip by remember { mutableStateOf<FleetTrip?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var lastGpsLabel by remember { mutableStateOf<String?>(null) }
    var sseStateLabel by remember { mutableStateOf("SSE idle") }
    val scope = rememberCoroutineScope()
    var sseJob by remember { mutableStateOf<Job?>(null) }
    var gpsJob by remember { mutableStateOf<Job?>(null) }
    var healthJob by remember { mutableStateOf<Job?>(null) }
    val context = LocalContext.current
    val fusedClient = remember { LocationServices.getFusedLocationProviderClient(context) }
    val locationPermission = rememberPermissionState(Manifest.permission.ACCESS_FINE_LOCATION)

    suspend fun refreshHealth() {
        try {
            val api = FleetApi(prefs.baseUrl, prefs.apiKey)
            val health = withContext(Dispatchers.IO) { api.health() }
            val healthOk = health.optBoolean("ok")
            if (!healthOk) {
                connected = false
                serverVersion = health.optString("version").takeIf { it.isNotBlank() }
                lastHealthAt = Instant.now()
                lastHealthLabel = "just now"
                status = FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false)
                error = null
                return
            }
            try {
                withContext(Dispatchers.IO) { api.verifyAuthenticatedAccess() }
                connected = true
                serverVersion = health.optString("version").takeIf { it.isNotBlank() }
                lastHealthAt = Instant.now()
                lastHealthLabel = "just now"
                status = FleetConnectionGate.statusLabel(healthOk = true, authSucceeded = true)
                error = null
            } catch (e: Exception) {
                connected = false
                serverVersion = health.optString("version").takeIf { it.isNotBlank() }
                lastHealthAt = Instant.now()
                lastHealthLabel = "just now"
                status = FleetConnectionGate.statusLabel(
                    healthOk = true,
                    authSucceeded = false,
                    authErrorMessage = e.message,
                )
                error = e.message
            }
        } catch (e: Exception) {
            connected = false
            status = FleetConnectionGate.statusLabel(healthOk = false, authSucceeded = false)
            lastHealthAt = Instant.now()
            lastHealthLabel = "just now"
            error = e.message
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            sseJob?.cancel()
            gpsJob?.cancel()
            healthJob?.cancel()
        }
    }

    LaunchedEffect(Unit) {
        if (!locationPermission.status.isGranted) {
            locationPermission.launchPermissionRequest()
        }
    }

    // Health poll every 30s while paired.
    LaunchedEffect(prefs.baseUrl, prefs.apiKey, prefs.vehicleId) {
        if (!prefs.isPaired()) return@LaunchedEffect
        healthJob?.cancel()
        healthJob = scope.launch {
            while (isActive) {
                refreshHealth()
                delay(30_000)
            }
        }
    }

    // Refresh relative "last health" label.
    LaunchedEffect(lastHealthAt) {
        val stamped = lastHealthAt ?: return@LaunchedEffect
        while (isActive) {
            val ageSec = Instant.now().epochSecond - stamped.epochSecond
            lastHealthLabel = when {
                ageSec < 5 -> "just now"
                ageSec < 60 -> "${ageSec}s ago"
                else -> "${ageSec / 60}m ago"
            }
            delay(5_000)
        }
    }

    // Resilient SSE with reconnect backoff.
    LaunchedEffect(prefs.baseUrl, prefs.apiKey, prefs.vehicleId) {
        if (!prefs.isPaired()) return@LaunchedEffect
        sseJob?.cancel()
        sseJob = scope.launch {
            try {
                val api = FleetApi(prefs.baseUrl, prefs.apiKey)
                FleetSseClient(api).eventsWithReconnect(
                    vehicleId = prefs.vehicleId,
                    onState = { state ->
                        scope.launch(Dispatchers.Main.immediate) {
                            sseStateLabel = when (state) {
                                is SseConnectionState.Listening -> "SSE listening"
                                is SseConnectionState.Reconnecting ->
                                    "Reconnecting in ${state.delaySeconds}s…"
                                is SseConnectionState.Stopped ->
                                    "SSE stopped${state.reason?.let { ": $it" } ?: ""}"
                            }
                        }
                    },
                ).collect { event ->
                    status = "SSE ${event.kind}"
                    if (event.kind == "tripPushed" && event.tripId != null) {
                        trip = withContext(Dispatchers.IO) { api.getTrip(event.tripId) }
                    }
                }
            } catch (e: Exception) {
                error = e.message
                sseStateLabel = "SSE stopped"
                status = "SSE stopped"
            }
        }
    }

    LaunchedEffect(trip?.id, connected, locationPermission.status.isGranted) {
        gpsJob?.cancel()
        val activeTrip = trip
        if (activeTrip == null || !connected || !locationPermission.status.isGranted) {
            gpsJob = null
            return@LaunchedEffect
        }
        gpsJob = scope.launch {
            var lastLat: Double? = null
            var lastLon: Double? = null
            while (isActive) {
                try {
                    val fix = currentLocation(fusedClient)
                    if (fix != null) {
                        val (lat, lon) = fix
                        val moved =
                            lastLat == null ||
                                lastLon == null ||
                                kotlin.math.abs(lat - lastLat!!) > 0.00005 ||
                                kotlin.math.abs(lon - lastLon!!) > 0.00005
                        if (moved) {
                            val recordedAt = Instant.now().toString()
                            withContext(Dispatchers.IO) {
                                FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                    trip = activeTrip,
                                    status = activeTrip.status,
                                    driverLatitude = lat,
                                    driverLongitude = lon,
                                    driverLocationRecordedAt = recordedAt,
                                )
                            }
                            lastLat = lat
                            lastLon = lon
                            lastGpsLabel = "%.5f, %.5f @ %s".format(lat, lon, recordedAt)
                            status = "GPS snapshot published"
                        }
                    }
                } catch (e: Exception) {
                    error = e.message
                }
                delay(20_000)
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Fleet driver", style = MaterialTheme.typography.headlineSmall)
                OutlinedButton(onClick = onReconfigure) { Text("Setup") }
            }

            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = if (connected) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.errorContainer
                    },
                ),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(FleetConnectionGate.badgeTitle(status))
                    Text(prefs.baseUrl, style = MaterialTheme.typography.bodySmall)
                    Text("Vehicle ${prefs.vehicleId}", style = MaterialTheme.typography.bodySmall)
                    serverVersion?.let {
                        Text("Server $it", style = MaterialTheme.typography.bodySmall)
                    }
                    lastHealthLabel?.let {
                        Text("Last health: $it", style = MaterialTheme.typography.bodySmall)
                    }
                    Text(sseStateLabel, style = MaterialTheme.typography.bodySmall)
                    lastGpsLabel?.let {
                        Text("Last GPS: $it", style = MaterialTheme.typography.bodySmall)
                    }
                    if (!locationPermission.status.isGranted) {
                        Text(
                            "Location permission needed for live dispatch pin",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        Button(onClick = { locationPermission.launchPermissionRequest() }) {
                            Text("Grant location")
                        }
                    }
                    OutlinedButton(
                        onClick = {
                            scope.launch { refreshHealth() }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Refresh now") }
                }
            }

            Button(
                onClick = {
                    scope.launch {
                        error = null
                        try {
                            val active = withContext(Dispatchers.IO) {
                                FleetApi(prefs.baseUrl, prefs.apiKey).activeTrip(prefs.vehicleId)
                            }
                            trip = active
                            status = if (active == null) "No active trip" else "Active ${active.status}"
                        } catch (e: Exception) {
                            error = e.message
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Check for dispatch") }

            Button(
                onClick = {
                    val current = trip ?: return@Button
                    scope.launch {
                        error = null
                        try {
                            val fix =
                                if (locationPermission.status.isGranted) {
                                    currentLocation(fusedClient)
                                } else {
                                    null
                                }
                            val recordedAt = if (fix != null) Instant.now().toString() else null
                            val updated = withContext(Dispatchers.IO) {
                                FleetApi(prefs.baseUrl, prefs.apiKey).publishSnapshot(
                                    trip = current,
                                    status = "accepted",
                                    driverLatitude = fix?.first,
                                    driverLongitude = fix?.second,
                                    driverLocationRecordedAt = recordedAt,
                                )
                            }
                            trip = updated
                            status = "Snapshot published · ${updated.status}"
                            if (fix != null) {
                                lastGpsLabel = "%.5f, %.5f".format(fix.first, fix.second)
                            }
                        } catch (e: Exception) {
                            error = e.message
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = trip != null,
            ) { Text("Accept / publish snapshot") }

            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

            trip?.let { t ->
                Spacer(modifier = Modifier.height(4.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text("Trip ${t.id}", style = MaterialTheme.typography.titleMedium)
                        Text("Status: ${t.status}")
                        t.stops.sortedBy { it.sequence }.forEach { stop ->
                            Text("${stop.role}: ${stop.label}")
                            Text(
                                "(${stop.latitude}, ${stop.longitude})",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            Text(
                "Full HGV navigation is C2 — gated separately.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@SuppressLint("MissingPermission")
private suspend fun currentLocation(
    client: com.google.android.gms.location.FusedLocationProviderClient,
): Pair<Double, Double>? {
    val token = CancellationTokenSource()
    val current = try {
        client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, token.token).await()
    } catch (_: Exception) {
        null
    }
    val location = current ?: client.lastLocation.await()
    if (location == null) return null
    // Skip very stale last-known fixes (>2 minutes).
    val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
    if (ageMs > 120_000) return null
    return location.latitude to location.longitude
}
