package com.routefinder.fleetdriver.ui

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetSseClient
import com.routefinder.fleetdriver.fleet.FleetTrip
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val PREFS = "fleet_driver"
private const val KEY_BASE = "base_url"
private const val KEY_API = "api_key"
private const val KEY_VEHICLE = "vehicle_id"

@Composable
fun DriverScreen() {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    var baseUrl by remember { mutableStateOf(prefs.getString(KEY_BASE, "http://10.0.2.2:8080") ?: "") }
    var apiKey by remember { mutableStateOf(prefs.getString(KEY_API, "") ?: "") }
    var vehicleId by remember { mutableStateOf(prefs.getString(KEY_VEHICLE, "") ?: "") }
    var status by remember { mutableStateOf("Idle") }
    var trip by remember { mutableStateOf<FleetTrip?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    var sseJob by remember { mutableStateOf<Job?>(null) }

    fun persist() {
        prefs.edit()
            .putString(KEY_BASE, baseUrl.trim())
            .putString(KEY_API, apiKey.trim())
            .putString(KEY_VEHICLE, vehicleId.trim())
            .apply()
    }

    DisposableEffect(Unit) {
        onDispose { sseJob?.cancel() }
    }

    MaterialTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("RouteFinder Fleet Driver (C1)", style = MaterialTheme.typography.headlineSmall)
                Text(
                    "Receive LAN trips. Full HGV navigation is C2 — gated on pilot renewals.",
                    style = MaterialTheme.typography.bodyMedium,
                )

                OutlinedTextField(
                    value = baseUrl,
                    onValueChange = { baseUrl = it },
                    label = { Text("Server base URL") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    label = { Text("API key (optional)") },
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = vehicleId,
                    onValueChange = { vehicleId = it },
                    label = { Text("Vehicle UUID") },
                    modifier = Modifier.fillMaxWidth(),
                )

                Button(
                    onClick = {
                        persist()
                        scope.launch {
                            error = null
                            try {
                                val health = withContext(Dispatchers.IO) {
                                    FleetApi(baseUrl, apiKey).health()
                                }
                                status = "Health ok=${health.optBoolean("ok")} version=${health.optString("version")}"
                            } catch (e: Exception) {
                                error = e.message
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Test /health") }

                Button(
                    onClick = {
                        persist()
                        scope.launch {
                            error = null
                            try {
                                val active = withContext(Dispatchers.IO) {
                                    FleetApi(baseUrl, apiKey).activeTrip(vehicleId.trim())
                                }
                                trip = active
                                status = if (active == null) "No active trip" else "Active ${active.status}"
                            } catch (e: Exception) {
                                error = e.message
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = vehicleId.isNotBlank(),
                ) { Text("Fetch active trip") }

                Button(
                    onClick = {
                        persist()
                        sseJob?.cancel()
                        sseJob = scope.launch {
                            error = null
                            status = "Listening for SSE…"
                            try {
                                val api = FleetApi(baseUrl, apiKey)
                                FleetSseClient(api).events(vehicleId.trim()).collect { event ->
                                    status = "SSE ${event.kind} trip=${event.tripId}"
                                    if (event.kind == "tripPushed" && event.tripId != null) {
                                        trip = withContext(Dispatchers.IO) { api.getTrip(event.tripId) }
                                    }
                                }
                            } catch (e: Exception) {
                                error = e.message
                                status = "SSE stopped"
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = vehicleId.isNotBlank(),
                ) { Text("Start SSE listen") }

                Button(
                    onClick = {
                        val current = trip ?: return@Button
                        persist()
                        scope.launch {
                            error = null
                            try {
                                val updated = withContext(Dispatchers.IO) {
                                    FleetApi(baseUrl, apiKey).publishSnapshot(current, "accepted")
                                }
                                trip = updated
                                status = "Snapshot published · ${updated.status}"
                            } catch (e: Exception) {
                                error = e.message
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = trip != null,
                ) { Text("Accept / publish snapshot") }

                Text("Status: $status")
                error?.let { Text("Error: $it", color = MaterialTheme.colorScheme.error) }

                trip?.let { t ->
                    Spacer(Modifier = Modifier.height(8.dp))
                    Text("Trip ${t.id}", style = MaterialTheme.typography.titleMedium)
                    Text("Status: ${t.status}")
                    t.stops.sortedBy { it.sequence }.forEach { stop ->
                        Text("${stop.role}: ${stop.label} (${stop.latitude}, ${stop.longitude})")
                    }
                }
            }
        }
    }
}
