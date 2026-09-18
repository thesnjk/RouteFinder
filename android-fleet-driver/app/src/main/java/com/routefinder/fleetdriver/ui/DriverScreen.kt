package com.routefinder.fleetdriver.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.routefinder.fleetdriver.fleet.FleetPreferences

/**
 * Root flow: Driver Terms → onboarding → fleet wizard → C2 navigation map.
 */
@Composable
fun DriverScreen() {
    val context = LocalContext.current
    val prefs = remember { FleetPreferences(context) }
    var showTerms by remember { mutableStateOf(!prefs.driverTermsAccepted) }
    var showOnboarding by remember { mutableStateOf(!prefs.onboardingSeen) }
    var showWizard by remember {
        mutableStateOf(!prefs.setupComplete || !prefs.isPaired())
    }

    MaterialTheme {
        when {
            showTerms -> {
                DriverTermsScreen(
                    onAccepted = {
                        prefs.driverTermsAccepted = true
                        showTerms = false
                    },
                )
            }
            showOnboarding -> {
                DriverOnboardingScreen(
                    onContinue = {
                        prefs.onboardingSeen = true
                        showOnboarding = false
                        if (!prefs.setupComplete || !prefs.isPaired()) {
                            showWizard = true
                        }
                    },
                )
            }
            showWizard -> {
                FleetSetupWizardScreen(
                    prefs = prefs,
                    onFinished = {
                        showWizard = false
                    },
                )
            }
            else -> {
                NavigationMapScreen(
                    prefs = prefs,
                    onReconfigure = {
                        prefs.setupComplete = false
                        showWizard = true
                    },
                )
            }
        }
    }
}
