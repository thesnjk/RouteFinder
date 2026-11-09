package com.routefinder.fleetdriver.ui

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.ButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.routefinder.fleetdriver.compliance.CanIDriveEvaluator
import com.routefinder.fleetdriver.compliance.ParkingAvailabilityTier
import com.routefinder.fleetdriver.compliance.ParkingBookCtaCopy
import com.routefinder.fleetdriver.compliance.ParkingBookPartner
import com.routefinder.fleetdriver.compliance.ParkingPartnerLinks
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.FleetConnectionGate
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
    val recordAudioPermission = rememberPermissionState(Manifest.permission.RECORD_AUDIO)
    val tachoImportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) viewModel.importTacho(uri)
    }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.evaluateParkingBookResumeOnForeground()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

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
                viewModel.ingestLocation(fix.first, fix.second, fix.third)
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
            parkingMarkers = viewModel.parkingMapMarkers,
            modifier = Modifier.fillMaxSize(),
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            if (viewModel.showParkingBookResumeBanner) {
                viewModel.pendingParkingBookReturn?.let { pending ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                        ),
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(pending.resumeMessage, style = MaterialTheme.typography.bodyMedium)
                            val pendingTier = pending.tier
                            if (pendingTier != null) {
                                Text(
                                    pendingTier.displayLabel,
                                    color = when (pendingTier) {
                                        ParkingAvailabilityTier.AMPLE -> MaterialTheme.colorScheme.primary
                                        ParkingAvailabilityTier.LIMITED -> MaterialTheme.colorScheme.tertiary
                                        ParkingAvailabilityTier.FULL -> MaterialTheme.colorScheme.error
                                    },
                                )
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = { viewModel.keepNavigatingAfterParkingBook() }) {
                                    Text("Keep nav")
                                }
                                OutlinedButton(onClick = { viewModel.dismissParkingBookReturn() }) {
                                    Text("Dismiss")
                                }
                            }
                            Text(
                                "Partner booking stays on their site — RouteFinder does not take payment.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.tertiary,
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }

            if (viewModel.parkingMapMarkers.isNotEmpty()) {
                OutlinedButton(
                    onClick = {
                        viewModel.parkingMapMarkers.firstOrNull()?.let { viewModel.selectParkingBookStop(it) }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Book ahead parking")
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            viewModel.selectedParkingBookStop?.let { stop ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                    ),
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(stop.label, style = MaterialTheme.typography.bodyMedium)
                        ParkingBookButtons(
                            latitude = stop.latitude,
                            longitude = stop.longitude,
                            label = stop.label,
                            stopId = stop.id,
                            tier = stop.tier,
                            viewModel = viewModel,
                        )
                        OutlinedButton(onClick = { viewModel.clearSelectedParkingBookStop() }) {
                            Text("Close")
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            viewModel.primaryRiskAdvisory?.let { risk ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.95f),
                    ),
                ) {
                    Text(
                        text = risk.message,
                        modifier = Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

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
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                FleetConnectionGate.badgeTitle(
                                    if (viewModel.connected) {
                                        "Connected"
                                    } else {
                                        viewModel.statusLabel
                                    },
                                ),
                                style = MaterialTheme.typography.titleSmall,
                            )
                            Text(
                                viewModel.sseLabel,
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

                    OutlinedTextField(
                        value = viewModel.regCheckUsernameDraft,
                        onValueChange = viewModel::updateRegCheckUsername,
                        label = { Text("RegCheck username") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        supportingText = {
                            Text("Optional — plate → dims on SSE job intake")
                        },
                    )
                    OutlinedTextField(
                        value = viewModel.tomTomApiKeyDraft,
                        onValueChange = viewModel::updateTomTomApiKey,
                        label = { Text("TomTom key (optional fallback)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        supportingText = {
                            Text(
                                if (viewModel.tomTomProxyConfigured) {
                                    "Fleet TomTom proxy on — driver key not required"
                                } else {
                                    "Or start fleet server with --tomtom-key"
                                },
                            )
                        },
                    )
                    OutlinedTextField(
                        value = viewModel.openWeatherApiKeyDraft,
                        onValueChange = viewModel::updateOpenWeatherApiKey,
                        label = { Text("OpenWeather key (optional fallback)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        supportingText = {
                            Text(
                                if (viewModel.openWeatherProxyConfigured) {
                                    "Fleet OpenWeather proxy on — driver key not required"
                                } else {
                                    "Or start fleet server with --openweather-key"
                                },
                            )
                        },
                    )

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
                                checked = !viewModel.voiceGuidanceMuted,
                                onCheckedChange = { viewModel.setVoiceEnabled(it) },
                            )
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Layby voice", style = MaterialTheme.typography.bodySmall)
                        Switch(
                            checked = viewModel.laybyVoiceAlertsEnabled,
                            onCheckedChange = { viewModel.updateLaybyVoiceAlertsEnabled(it) },
                        )
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Button(
                            onClick = {
                                if (!recordAudioPermission.status.isGranted) {
                                    recordAudioPermission.launchPermissionRequest()
                                    return@Button
                                }
                                if (viewModel.voiceListening) {
                                    viewModel.cancelVoiceListen()
                                } else {
                                    viewModel.startVoiceListen()
                                }
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text(if (viewModel.voiceListening) "Listening…" else "Talk")
                        }
                        OutlinedButton(
                            onClick = { viewModel.breakNow() },
                            enabled = viewModel.routeCoordinates.size >= 2,
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Break Now")
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
                    viewModel.currentInstruction?.laneGuidance?.let { lanes ->
                        // Hierarchy matches iOS LaneGuidanceBanner: phrase + onto street, then strip.
                        Text(
                            lanes.guidanceText,
                            style = MaterialTheme.typography.bodySmall,
                        )
                        viewModel.currentInstruction?.roadName?.takeIf { it.isNotBlank() }?.let { road ->
                            Text(
                                "onto ${road.take(48)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.tertiary,
                            )
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            lanes.lanes.forEachIndexed { index, arrow ->
                                val recommended = index in lanes.recommendedIndices
                                Text(
                                    lanes.symbol(arrow),
                                    style = MaterialTheme.typography.titleMedium,
                                    color = if (recommended) {
                                        MaterialTheme.colorScheme.primary
                                    } else {
                                        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                                    },
                                )
                            }
                        }
                    }
                    viewModel.activeTrip?.let {
                        Text("Fleet trip ${it.status}", style = MaterialTheme.typography.bodySmall)
                    }
                    viewModel.timeWindowLines.forEach { line ->
                        Text(line, style = MaterialTheme.typography.bodySmall)
                    }
                    viewModel.tollSummaryMessage?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "Check operator — indicative only; not a live tariff.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                    viewModel.activeTollAdvisory?.let { toll ->
                        val dist = viewModel.activeTollDistanceMeters
                        val distLabel = when {
                            dist == null -> null
                            dist >= 1000 -> String.format("%.1f km", dist / 1000.0)
                            else -> "${dist.toInt()} m"
                        }
                        val cost = toll.indicativeCostLabel
                        val title = if (distLabel != null) "${toll.name} · $distLabel" else toll.name
                        Text(title, style = MaterialTheme.typography.bodyMedium)
                        if (cost != null) {
                            Text(cost, style = MaterialTheme.typography.bodySmall)
                        }
                        Text(toll.hint, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
                    }
                    viewModel.lezAdvisoryMessage?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
                    }
                    viewModel.laybyAdvisory?.let { advisory ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(advisory.message, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                            Text(
                                advisory.tier.displayLabel,
                                style = MaterialTheme.typography.bodyMedium,
                                color = when (advisory.tier) {
                                    ParkingAvailabilityTier.AMPLE -> MaterialTheme.colorScheme.primary
                                    ParkingAvailabilityTier.LIMITED -> MaterialTheme.colorScheme.tertiary
                                    ParkingAvailabilityTier.FULL -> MaterialTheme.colorScheme.error
                                },
                            )
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { viewModel.reportLaybyFull() }) {
                                Text("Looks full")
                            }
                            OutlinedButton(onClick = { viewModel.reportLaybySpaces() }) {
                                Text("Spaces")
                            }
                        }
                        ParkingBookButtons(
                            latitude = advisory.site.coordinate.latitude,
                            longitude = advisory.site.coordinate.longitude,
                            label = advisory.site.name,
                            stopId = advisory.site.id,
                            tier = advisory.tier,
                            viewModel = viewModel,
                        )
                        Text(
                            "crowd estimate — not live bay count",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    } ?: viewModel.laybyAdvisoryMessage?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall)
                    }
                    viewModel.canIDriveStatus?.let { status ->
                        val chip = if (status.canDrive) "Can drive" else "Break"
                        val sourceTag = when {
                            status.usesPartnerAdvisory -> " · Partner"
                            status.usesImportedCard -> " · Imported"
                            else -> ""
                        }
                        Text(
                            "$chip$sourceTag",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        val shortReason = status.reason
                            .substringBefore(CanIDriveEvaluator.LEGAL_DISCLAIMER)
                            .trim()
                        Text(shortReason, style = MaterialTheme.typography.bodySmall)
                        Text(
                            "planning aid — not legal VU",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                    viewModel.importedTachoSummary?.let { summary ->
                        Text(
                            "Card: ${summary.sourceFileName}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                    viewModel.tachoImportError?.let {
                        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }
                    viewModel.hosAdvisoryMessage?.let {
                        Text(it, style = MaterialTheme.typography.bodySmall)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { viewModel.resetHosBreak() }) { Text("Record break") }
                        OutlinedButton(
                            onClick = {
                                tachoImportLauncher.launch(
                                    arrayOf(
                                        "application/json",
                                        "text/plain",
                                        "application/octet-stream",
                                        "*/*",
                                    ),
                                )
                            },
                        ) {
                            Text("Import tacho")
                        }
                        if (viewModel.importedTachoSummary != null) {
                            OutlinedButton(onClick = { viewModel.clearImportedTacho() }) {
                                Text("Clear")
                            }
                        }
                    }
                    OutlinedTextField(
                        value = viewModel.emissionClassDraft,
                        onValueChange = viewModel::updateEmissionClass,
                        label = { Text("Euro class (LEZ)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        OutlinedTextField(
                            value = viewModel.trailerCountDraft.toString(),
                            onValueChange = viewModel::updateTrailerCount,
                            label = { Text("Trailers (0–3)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                        )
                        OutlinedTextField(
                            value = String.format("%.1f", viewModel.lengthMetersDraft),
                            onValueChange = viewModel::updateLengthMeters,
                            label = { Text("Length m") },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                        )
                    }
                    Text(
                        "Length is bumper-to-bumper (ORS). Trailers 0 = rigid, ≥1 = artic.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.tertiary,
                    )
                    viewModel.lastInspectionSummary?.let {
                        Text(
                            "Walkaround: ${it.defectCount} defect(s), ${it.photoCount} photo(s)",
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    if (viewModel.lastWalkaroundPdfBytes != null) {
                        Text("Walkaround PDF ready (${viewModel.lastWalkaroundPdfBytes!!.size / 1024} KB)", style = MaterialTheme.typography.bodySmall)
                    }
                    OutlinedButton(
                        onClick = { viewModel.openWalkaround() },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("DVSA walkaround")
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

        if (viewModel.showWalkaround) {
            InspectionWalkaroundDialog(
                items = viewModel.walkaroundItems,
                onUpdate = { index, item -> viewModel.updateWalkaroundItem(index, item) },
                onComplete = { viewModel.completeWalkaround() },
                onDismiss = { viewModel.dismissWalkaround() },
            )
        }
    }
}

@Composable
private fun ParkingBookButtons(
    latitude: Double,
    longitude: Double,
    label: String,
    stopId: String,
    tier: ParkingAvailabilityTier?,
    viewModel: NavigationViewModel,
) {
    val context = LocalContext.current
    val emphasizeTravis = ParkingBookCtaCopy.emphasizesTravis(tier)
    val secondary = ParkingBookCtaCopy.usesSecondaryBookStyle(tier)
    fun openPartner(partner: ParkingBookPartner) {
        viewModel.noteParkingBookOpened(
            id = stopId,
            label = label,
            latitude = latitude,
            longitude = longitude,
            partner = partner,
            tier = tier,
        )
        val uri = when (partner) {
            ParkingBookPartner.TRAVIS -> ParkingPartnerLinks.travisUrl(latitude, longitude, label)
            ParkingBookPartner.SNAP -> ParkingPartnerLinks.snapUrl(latitude, longitude, label)
        }
        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (emphasizeTravis && !secondary) {
            Button(onClick = { openPartner(ParkingBookPartner.TRAVIS) }) {
                Text("Book (TRAVIS)", fontWeight = FontWeight.SemiBold)
            }
        } else {
            OutlinedButton(onClick = { openPartner(ParkingBookPartner.TRAVIS) }) {
                Text("Book (TRAVIS)")
            }
        }
        OutlinedButton(onClick = { openPartner(ParkingBookPartner.SNAP) }) {
            Text("Book (SNAP)")
        }
    }
    ParkingBookCtaCopy.caption(tier)?.let { caption ->
        Text(
            caption,
            style = MaterialTheme.typography.bodySmall,
            color = if (tier == ParkingAvailabilityTier.FULL) {
                MaterialTheme.colorScheme.error
            } else {
                MaterialTheme.colorScheme.tertiary
            },
        )
    }
    Text(
        "Opens partner site — booking and fees are between you and the operator.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.tertiary,
    )
}

@SuppressLint("MissingPermission")
private suspend fun currentLocation(
    client: com.google.android.gms.location.FusedLocationProviderClient,
): Triple<Double, Double, Double?>? {
    val token = CancellationTokenSource()
    val current = try {
        client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, token.token).await()
    } catch (_: Exception) {
        null
    }
    val location = current ?: client.lastLocation.await() ?: return null
    val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
    if (ageMs > 120_000) return null
    val bearing = if (location.hasBearing()) location.bearing.toDouble() else null
    return Triple(location.latitude, location.longitude, bearing)
}
