#if DEBUG
import Contracts
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Applies launch-argument overrides for RouteFinderApp UI tests.
enum UITestLaunchConfigurator {
    static func applyIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("UITEST_SKIP_ONBOARDING")
            || arguments.contains("UITEST_SKIP_AUTH") else {
            return
        }
        NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
        NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true)
        #if canImport(UIKit)
        UIView.setAnimationsEnabled(false)
        #endif
    }
}
#endif
