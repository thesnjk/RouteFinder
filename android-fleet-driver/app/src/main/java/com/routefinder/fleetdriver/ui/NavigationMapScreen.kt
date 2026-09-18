package com.routefinder.fleetdriver.ui

import android.Manifest
import android.annotation.SuppressLint
import android.os.SystemClock
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.map.MapLibreMapView
import com.routefinder.fleetdriver.nav.NavigationPhase
import com.routefinder.fleetdriver.nav.NavigationViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.tasks.await

/**
 * C2 primary surface: MapLibre map + geocode / Find route / Start / Rehearse + fleet status.
 */
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun NavigationMapScreen(
    prefs: FleetPreferences,
    onReconfigure: () -> Unit,
    viewModel: NavigationViewModel = viewModel(),
) {
    val context = LocalContext.current
    val fused = remember { LocationServices.getFusedLocationProviderClient(context) }
    val locationPermission = rememberPermissionState(Manifest.permission.ACCESS_FINE_LOCATION)

    LaunchedEffect(Unit) {
        if (!locationPermission.status.isGranted) {
            locationPermission.launchPermissionRequest()
        }
        viewModel.startFleetLoops()
        viewModel.refreshHealth()
    }

    LaunchedEffect(locationPermission.status.isGranted, viewModel.phase) {
        if (!locationPermission.status.isGranted) return@LaunchedEffect
        if (viewModel.phase != NavigationPhase.NAVIGATING) return@LaunchedEffect
        while (isActive && viewModel.phase == NavigationPhase.NAVIGATING) {
            val fix = currentLocation(fused)
            if (fix != null) {
                viewModel.ingestLocation(fix.first, fix.second)
            }
            delay(2_000)
        }
    }

    viewModel.toastMessage?.let { msg ->
        LaunchedEffect(msg) {
            delay(3_500)
            viewModel.clearToast()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        MapLibreMapView(
            routeCoordinates = viewModel.routeCoordinates,
            followLat = viewModel.followLat,
            followLon = viewModel.followLon,
            modifier = Modifier.fillMaxSize(),
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
                ),
                elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column {
                            Text(
                                if (viewModel.connected) "Connected" else "Offline",
                                style = MaterialTheme.typography.titleSmall,
                            )
                            Text(
                                "${viewModel.sseLabel} · ${viewModel.statusLabel}",
                                style = MaterialTheme.typography.bodySmall,
                            )
                            if (!viewModel.orsConfigured) {
                                Text(
                                    "Fleet ORS proxy may be off — start server with --ors-key",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.error,
                                )
                            }
                        }
                        OutlinedButton(onClick = onReconfigure) { Text("Setup") }
                    }

                    viewModel.toastMessage?.let {
                        Text(it, color = MaterialTheme.colorScheme.primary)
                    }

                    GeocodeSearchField(
                        label = "Origin",
                        value = viewModel.origin.label,
                        suggestions = viewModel.originSuggestions,
                        onValueChange = viewModel::searchOrigin,
                        onSelect = viewModel::selectOrigin,
                    )
                    GeocodeSearchField(
                        label = "Destination",
                        value = viewModel.destination.label,
                        suggestions = viewModel.destinationSuggestions,
                        onValueChange = viewModel::searchDestination,
                        onSelect = viewModel::selectDestination,
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Button(
                            onClick = { viewModel.findRoute() },
                            enabled = !viewModel.isCalculating,
                            modifier = Modifier.weight(1f),
                        ) {
                            if (viewModel.isCalculating) {
                                CircularProgressIndicator(
                                    modifier = Modifier.height(18.dp),
                                    strokeWidth = 2.dp,
                                )
                            } else {
                                Text("Find route")
                            }
                        }
                        when (viewModel.phase) {
                            NavigationPhase.ROUTE_LOADED, NavigationPhase.COMPLETED -> {
                                Button(
                                    onClick = { viewModel.startNavigation() },
                                    modifier = Modifier.weight(1f),
                                ) { Text("Start") }
                            }
                            NavigationPhase.NAVIGATING -> {
                                OutlinedButton(
                                    onClick = { viewModel.stopNavigation() },
                                    modifier = Modifier.weight(1f),
                                ) { Text("Stop") }
                            }
                            else -> Spacer(modifier = Modifier.weight(1f))
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        OutlinedButton(
                            onClick = { viewModel.rehearseRoute() },
                            enabled = viewModel.phase == NavigationPhase.ROUTE_LOADED ||
                                viewModel.phase == NavigationPhase.NAVIGATING ||
                                viewModel.phase == NavigationPhase.COMPLETED,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text(if (viewModel.isRehearsing) "Rehearsing…" else "Rehearse")
                        }
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Voice", style = MaterialTheme.typography.bodySmall)
                            Switch(
                                checked = prefs.voiceGuidanceEnabled,
                                onCheckedChange = { viewModel.setVoiceEnabled(it) },
                            )
                        }
                    }

                    viewModel.distanceLabel?.let {
                        Text("Distance: $it", style = MaterialTheme.typography.bodyMedium)
                    }
                    viewModel.etaLabel?.let {
                        Text("ORS ETA: $it", style = MaterialTheme.typography.bodyMedium)
                    }
                    viewModel.physicsEtaLabel?.let {
                        Text("Physics ETA: $it", style = MaterialTheme.typography.bodyMedium)
                    }
                    viewModel.progress?.let { p ->
                        Text(
                            "Maneuver ${p.currentManeuverIndex + 1} · ${NavigationViewModel.formatDistance(p.distanceToNextManeuverMeters)}",
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    viewModel.activeTrip?.let {
                        Text("Fleet trip ${it.status}", style = MaterialTheme.typography.bodySmall)
                    }
                    viewModel.errorMessage?.let {
                        Text(it, color = MaterialTheme.colorScheme.error)
                    }
                    if (!locationPermission.status.isGranted) {
                        Button(onClick = { locationPermission.launchPermissionRequest() }) {
                            Text("Grant location")
                        }
                    }
                }
            }
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
    val location = current ?: client.lastLocation.await() ?: return null
    val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
    if (ageMs > 120_000) return null
    return location.latitude to location.longitude
}
