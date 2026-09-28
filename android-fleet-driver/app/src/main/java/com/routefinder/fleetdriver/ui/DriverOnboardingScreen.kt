package com.routefinder.fleetdriver.ui

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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * First-run C2 onboarding (fleet pair + HGV navigate via office ORS proxy).
 */
@Composable
fun DriverOnboardingScreen(
    onContinue: () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("RouteFinder Fleet Driver", style = MaterialTheme.typography.headlineSmall)
            Text(
                "Receive trips and navigate HGV routes using the office fleet server. No personal HeiGIT key.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            OnboardingCard(
                title = "Pair with the office server",
                body = "Discover the Mac on your LAN (or paste http://<mac-ip>:8080), test connection until Connected, then scan the vehicle QR from Mac or web dispatch.",
            )
            OnboardingCard(
                title = "Find route & navigate",
                body = "Search addresses, calculate an HGV route via the office ORS proxy, then Start for metric turn-by-turn voice. Rehearse estimates a physics ETA.",
            )
            OnboardingCard(
                title = "Live GPS pin",
                body = "With location permission, this phone publishes a GPS fix about every 20 seconds while navigating — Mac and web dispatch show your pin.",
            )

            Text(
                "Android Auto and offline map packs remain later releases.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = onContinue,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Get started") }
            OutlinedButton(
                onClick = onContinue,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Skip") }
        }
    }
}

@Composable
private fun OnboardingCard(title: String, body: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(body, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
