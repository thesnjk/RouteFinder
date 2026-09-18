package com.routefinder.fleetdriver.ui

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
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Non-dismissible Driver Terms gate (mirrors iOS ProductOnboardingSheet liability section).
 */
@Composable
fun DriverTermsScreen(
    onAccepted: () -> Unit,
) {
    var accepted by remember { mutableStateOf(false) }

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Driver Terms", style = MaterialTheme.typography.headlineSmall)
            Text(
                DRIVER_TERMS_BODY,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "Privacy: $LEGAL_PRIVACY_URL — Terms: $LEGAL_TERMS_URL. Replace domain after you host Docs/legal/site/.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Checkbox(
                    checked = accepted,
                    onCheckedChange = { accepted = it },
                )
                Text(
                    DRIVER_TERMS_ACCEPTANCE_LABEL,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = onAccepted,
                enabled = accepted,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Continue")
            }
        }
    }
}

/** Keep aligned with Docs/legal/driver-terms.md and iOS ProductOnboardingSheet. */
val DRIVER_TERMS_BODY = """
Routing, physics rehearsal, layby suggestions, HOS advisories, and turn-by-turn guidance in RouteFinder are advisory planning aids only.

Physical road signs, bridge height and weight plates, temporary restrictions, and immediate traffic conditions always supersede navigation instructions. Bridge strikes and constraint violations can trigger Traffic Commissioner action against operators and driver conduct hearings.

You (and your operator, where applicable) remain solely responsible for safe, lawful driving and for verifying vehicle dimensions against the route before departure. The developer accepts no liability for incorrect routing, missed restrictions, or reliance on advisory outputs.
""".trimIndent()

const val DRIVER_TERMS_ACCEPTANCE_LABEL =
    "I understand routing and guidance are advisory only; physical signs and bridge plates always supersede the app; the developer is not liable for incorrect routing."

/** Placeholder HTTPS URLs — must match ProductLegalDocuments / Docs/legal/site/README.md after publish. */
const val LEGAL_PRIVACY_URL = "https://routefinder.app/legal/privacy"
const val LEGAL_TERMS_URL = "https://routefinder.app/legal/terms"
