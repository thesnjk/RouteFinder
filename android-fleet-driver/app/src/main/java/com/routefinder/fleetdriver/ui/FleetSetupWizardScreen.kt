package com.routefinder.fleetdriver.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.routefinder.fleetdriver.fleet.DiscoveredFleetServer
import com.routefinder.fleetdriver.fleet.FleetApi
import com.routefinder.fleetdriver.fleet.FleetBonjourDiscovery
import com.routefinder.fleetdriver.fleet.FleetPreferences
import com.routefinder.fleetdriver.fleet.VehicleQRParser
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class WizardStep(val index: Int) {
    Enable(0),
    Discover(1),
    Test(2),
    Vehicle(3),
    Done(4),
}

/**
 * Five-step fleet setup wizard mirroring iOS FleetSetupWizardView.
 */
@Composable
fun FleetSetupWizardScreen(
    prefs: FleetPreferences,
    onFinished: () -> Unit,
) {
    val context = LocalContext.current
    var step by remember { mutableStateOf(WizardStep.Enable) }
    var baseUrl by remember { mutableStateOf(prefs.baseUrl) }
    var apiKey by remember { mutableStateOf(prefs.apiKey) }
    var vehicleId by remember { mutableStateOf(prefs.vehicleId) }
    var connectionKind by remember { mutableStateOf(prefs.connectionKind) }
    var status by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var connected by remember { mutableStateOf(false) }
    var showScanner by remember { mutableStateOf(false) }
    var discovering by remember { mutableStateOf(false) }
    var discoveryStatus by remember { mutableStateOf<String?>(null) }
    var discovered by remember { mutableStateOf<List<DiscoveredFleetServer>>(emptyList()) }
    var checkDispatchStatus by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val isHosted = connectionKind == "hosted"

    fun saveVehicleAndFinishStep(uuid: String) {
        vehicleId = uuid
        prefs.vehicleId = uuid
        prefs.baseUrl = baseUrl
        prefs.apiKey = apiKey
        step = WizardStep.Done
    }

    if (showScanner) {
        VehicleQRScannerScreen(
            onUuidScanned = { uuid ->
                showScanner = false
                error = null
                saveVehicleAndFinishStep(uuid)
            },
            onCancel = { showScanner = false },
        )
        return
    }

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Fleet setup", style = MaterialTheme.typography.headlineSmall)
            Text(
                "Step ${step.index + 1} of ${WizardStep.entries.size}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            LinearProgressIndicator(
                progress = { (step.index + 1).toFloat() / WizardStep.entries.size },
                modifier = Modifier.fillMaxWidth(),
            )
            Text(titleFor(step, isHosted), style = MaterialTheme.typography.titleLarge)
            Text(
                subtitleFor(step, isHosted),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            when (step) {
                WizardStep.Enable -> {
                    WizardCard(title = "Enable fleet sync") {
                        Text(
                            if (isHosted) {
                                "Use a hosted HTTPS fleet URL from your operator. Works on cellular — no office Wi‑Fi required."
                            } else {
                                "Drivers stay on the same Wi‑Fi as the office Mac. Trips arrive via SSE — no cloud account."
                            },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    connectionKind = "lan"
                                    prefs.connectionKind = "lan"
                                },
                            ) { Text(if (!isHosted) "LAN ✓" else "Office LAN") }
                            OutlinedButton(
                                onClick = {
                                    connectionKind = "hosted"
                                    prefs.connectionKind = "hosted"
                                },
                            ) { Text(if (isHosted) "Hosted ✓" else "Hosted (HTTPS)") }
                        }
                        Text(
                            if (isHosted) {
                                "Next: paste the HTTPS base URL and org bearer token."
                            } else {
                                "Next: find the office server on the LAN (or paste the Mac URL)."
                            },
                        )
                    }
                }

                WizardStep.Discover -> {
                    WizardCard(title = if (isHosted) "Enter hosted URL" else "Find the office server") {
                        OutlinedTextField(
                            value = baseUrl,
                            onValueChange = {
                                baseUrl = it
                                if (it.trim().lowercase().startsWith("https://")) {
                                    connectionKind = "hosted"
                                    prefs.connectionKind = "hosted"
                                }
                            },
                            label = {
                                Text(if (isHosted) "Hosted fleet URL (https://…)" else "Server base URL")
                            },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        )
                        OutlinedTextField(
                            value = apiKey,
                            onValueChange = { apiKey = it },
                            label = {
                                Text(
                                    if (isHosted) {
                                        "Org bearer token"
                                    } else {
                                        "API key (if server uses --api-key)"
                                    },
                                )
                            },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            visualTransformation = PasswordVisualTransformation(),
                        )
                        Text(
                            if (isHosted) {
                                "Example: https://fleet.yourdomain.com — never paste the operator ORS key."
                            } else {
                                "Example: http://192.168.1.10:8080 · Emulator: http://10.0.2.2:8080"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        if (!isHosted) {
                            Button(
                                onClick = {
                                    discovering = true
                                    discoveryStatus = "Scanning LAN…"
                                    discovered = emptyList()
                                    error = null
                                    scope.launch {
                                        try {
                                            val servers = withContext(Dispatchers.Main) {
                                                FleetBonjourDiscovery.discover(context)
                                            }
                                            discovered = servers
                                            discoveryStatus = if (servers.isEmpty()) {
                                                "No servers found. Paste the Mac LAN URL instead."
                                            } else {
                                                "Found ${servers.size} server(s)."
                                            }
                                        } catch (e: Exception) {
                                            discoveryStatus = null
                                            error = e.message ?: "Discovery failed"
                                        } finally {
                                            discovering = false
                                        }
                                    }
                                },
                                enabled = !discovering,
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text(if (discovering) "Discovering…" else "Discover on LAN") }
                            discoveryStatus?.let {
                                Text(it, style = MaterialTheme.typography.bodySmall)
                            }
                            discovered.forEach { server ->
                                Card(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            baseUrl = server.baseUrl
                                            discoveryStatus = "Selected ${server.displayName}"
                                        },
                                    colors = CardDefaults.cardColors(
                                        containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                                    ),
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(server.displayName, style = MaterialTheme.typography.titleSmall)
                                        Text(server.baseUrl, style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                            }
                        }
                        error?.let {
                            Text(it, color = MaterialTheme.colorScheme.error)
                        }
                    }
                }

                WizardStep.Test -> {
                    WizardCard(title = "Confirm connection") {
                        Text(if (connected) "Connected" else "Not connected yet")
                        status?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                        error?.let {
                            Text(it, color = MaterialTheme.colorScheme.error)
                        }
                        Button(
                            onClick = {
                                prefs.baseUrl = baseUrl
                                prefs.apiKey = apiKey
                                prefs.connectionKind = connectionKind
                                scope.launch {
                                    error = null
                                    try {
                                        val health = withContext(Dispatchers.IO) {
                                            FleetApi(baseUrl, apiKey).health()
                                        }
                                        connected = health.optBoolean("ok")
                                        status = "Health ok=${health.optBoolean("ok")} version=${health.optString("version")}"
                                    } catch (e: Exception) {
                                        connected = false
                                        error = e.message ?: "Connection failed"
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Test /health") }
                        Text(
                            if (isHosted) {
                                "Hosted gateway must respond on /health. Use your org bearer token only."
                            } else {
                                "Same Wi‑Fi as the dispatch Mac. Routing API keys stay on the server when ORS proxy is enabled."
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                WizardStep.Vehicle -> {
                    WizardCard(title = "Pair this vehicle") {
                        OutlinedTextField(
                            value = vehicleId,
                            onValueChange = { vehicleId = it },
                            label = { Text("Vehicle UUID") },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        Text(
                            "Scan the QR shown in Mac Dispatch or web dispatch, or paste the UUID.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Button(
                            onClick = { showScanner = true },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Scan QR") }
                        error?.let {
                            Text(it, color = MaterialTheme.colorScheme.error)
                        }
                    }
                }

                WizardStep.Done -> {
                    WizardCard(title = "You're paired") {
                        Text("Server: $baseUrl")
                        Text("Vehicle: $vehicleId")
                        Text("Trip receive is ready. Check for dispatch on the home screen.")
                        Button(
                            onClick = {
                                scope.launch {
                                    checkDispatchStatus = "Checking…"
                                    try {
                                        val active = withContext(Dispatchers.IO) {
                                            FleetApi(baseUrl, apiKey).activeTrip(vehicleId)
                                        }
                                        checkDispatchStatus = if (active == null) {
                                            "No active trip yet — wait for dispatch push."
                                        } else {
                                            "Active trip ${active.status} · ${active.stops.size} stops"
                                        }
                                    } catch (e: Exception) {
                                        checkDispatchStatus = e.message ?: "Check failed"
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Check for dispatch now") }
                        checkDispatchStatus?.let {
                            Text(it, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                OutlinedButton(
                    onClick = {
                        step = when (step) {
                            WizardStep.Enable -> WizardStep.Enable
                            WizardStep.Discover -> WizardStep.Enable
                            WizardStep.Test -> WizardStep.Discover
                            WizardStep.Vehicle -> WizardStep.Test
                            WizardStep.Done -> WizardStep.Vehicle
                        }
                    },
                    enabled = step != WizardStep.Enable,
                ) { Text("Back") }

                Button(
                    onClick = {
                        error = null
                        when (step) {
                            WizardStep.Enable -> {
                                prefs.connectionKind = connectionKind
                                step = WizardStep.Discover
                            }
                            WizardStep.Discover -> {
                                val trimmed = baseUrl.trim()
                                if (trimmed.isEmpty()) {
                                    error = if (isHosted) {
                                        "Enter the hosted HTTPS URL."
                                    } else {
                                        "Enter a server URL or discover on LAN."
                                    }
                                } else if (isHosted && !trimmed.lowercase().startsWith("https://")) {
                                    error = "Hosted mode requires an https:// URL."
                                } else {
                                    prefs.baseUrl = baseUrl
                                    prefs.apiKey = apiKey
                                    prefs.connectionKind = connectionKind
                                    connected = false
                                    step = WizardStep.Test
                                }
                            }
                            WizardStep.Test -> {
                                if (!connected) {
                                    error = "Test /health until Connected before continuing."
                                } else {
                                    step = WizardStep.Vehicle
                                }
                            }
                            WizardStep.Vehicle -> {
                                val parsed = VehicleQRParser.parse(vehicleId)
                                if (parsed == null) {
                                    error = "Enter a valid vehicle UUID or scan a QR."
                                } else {
                                    saveVehicleAndFinishStep(parsed)
                                }
                            }
                            WizardStep.Done -> {
                                prefs.setupComplete = true
                                onFinished()
                            }
                        }
                    },
                ) {
                    Text(if (step == WizardStep.Done) "Finish" else "Next")
                }
            }
        }
    }
}

private fun titleFor(step: WizardStep, isHosted: Boolean): String = when (step) {
    WizardStep.Enable -> "Enable fleet sync"
    WizardStep.Discover -> if (isHosted) "Enter hosted URL" else "Find the office server"
    WizardStep.Test -> "Confirm connection"
    WizardStep.Vehicle -> "Pair this vehicle"
    WizardStep.Done -> "Ready"
}

private fun subtitleFor(step: WizardStep, isHosted: Boolean): String = when (step) {
    WizardStep.Enable ->
        if (isHosted) {
            "Connect this device to your operator’s hosted fleet gateway."
        } else {
            "Connect this device to RouteFinderFleetServer on the office LAN."
        }
    WizardStep.Discover ->
        if (isHosted) {
            "Paste the HTTPS base URL and org bearer token."
        } else {
            "Use LAN discovery or paste the Mac’s LAN URL."
        }
    WizardStep.Test -> "Make sure /health responds before pairing a vehicle."
    WizardStep.Vehicle -> "Each truck has one UUID from the dispatch console."
    WizardStep.Done -> "Setup complete for this device."
}

@Composable
private fun WizardCard(
    title: String,
    content: @Composable () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}
