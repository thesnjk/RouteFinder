#if DEBUG
import Contracts
import DataLayer
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Applies launch-argument overrides for RouteFinderApp UI tests.
public enum UITestLaunchConfigurator {
    /// Interprets `UITEST_*` process arguments and writes workspace overrides.
    public static func applyIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("UITEST_SKIP_ONBOARDING")
            || arguments.contains("UITEST_SKIP_AUTH")
            || arguments.contains("UITEST_SEED_ROUTE")
            || arguments.contains("UITEST_MOCK_ORS_KEY")
            || arguments.contains("UITEST_CAR_MODE")
            || arguments.contains("UITEST_HGV_MODE")
            || arguments.contains("UITEST_RESET_ONBOARDING")
            || arguments.contains("UITEST_PEEK_SHEET")
            || arguments.contains("UITEST_OPEN_SETTINGS")
            || arguments.contains("UITEST_SKIP_ROLE_PICKER")
            || arguments.contains("UITEST_RESET_ROLE_PICKER")
        guard isUITest else { return }

        #if canImport(UIKit)
        UIView.setAnimationsEnabled(false)
        #endif

        if arguments.contains("UITEST_RESET_ROLE_PICKER") {
            NavigationWorkspaceSettings.saveHasCompletedRoleSelection(false)
            NavigationWorkspaceSettings.saveHasCompletedRoleFollowUp(false)
            NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
            NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true)
            NavigationWorkspaceSettings.saveHasCompletedVehicleModeOnboarding(true)
        } else if arguments.contains("UITEST_RESET_ONBOARDING") {
            // Product sheet already seen so VehicleModeOnboardingSheet can present.
            NavigationWorkspaceSettings.saveHasCompletedRoleSelection(true)
            NavigationWorkspaceSettings.saveLaunchRole(.driver)
            NavigationWorkspaceSettings.saveHasCompletedRoleFollowUp(true)
            NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
            NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true)
            NavigationWorkspaceSettings.saveHasCompletedVehicleModeOnboarding(false)
        } else if arguments.contains("UITEST_SKIP_ONBOARDING")
            || arguments.contains("UITEST_SKIP_AUTH")
            || arguments.contains("UITEST_SEED_ROUTE")
            || arguments.contains("UITEST_SKIP_ROLE_PICKER") {
            NavigationWorkspaceSettings.saveHasCompletedRoleSelection(true)
            if NavigationWorkspaceSettings.loadLaunchRole() == nil {
                NavigationWorkspaceSettings.saveLaunchRole(.driver)
            }
            NavigationWorkspaceSettings.saveHasCompletedRoleFollowUp(true)
            NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
            NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true)
            NavigationWorkspaceSettings.saveHasCompletedVehicleModeOnboarding(true)
        }

        if arguments.contains("UITEST_MOCK_ORS_KEY") {
            VehicleProfileStore.saveORSAPIKey("uitest-mock-key")
        }

        if arguments.contains("UITEST_CAR_MODE") || arguments.contains("UITEST_HGV_MODE") {
            var snapshot = VehicleWorkspaceSettings.load() ?? VehicleWorkspaceSnapshot()
            snapshot.isHGVMode = arguments.contains("UITEST_HGV_MODE")
            VehicleWorkspaceSettings.save(snapshot)
        }

        if arguments.contains("UITEST_SEED_ROUTE") {
            UserDefaults.standard.set(true, forKey: "RouteFinder.uitestSeedRoute")
        } else {
            UserDefaults.standard.set(false, forKey: "RouteFinder.uitestSeedRoute")
        }
        UserDefaults.standard.set(
            arguments.contains("UITEST_PEEK_SHEET"),
            forKey: "RouteFinder.uitestPeekSheet"
        )
        UserDefaults.standard.set(
            arguments.contains("UITEST_OPEN_SETTINGS"),
            forKey: "RouteFinder.uitestOpenSettings"
        )
    }
}
#endif
