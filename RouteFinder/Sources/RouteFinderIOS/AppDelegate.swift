#if os(iOS)
import CarPlay
import UIKit

#if canImport(CarPlayUI)
import CarPlayUI
#endif

/// Application delegate hosting lifecycle hooks for CarPlay scene connectivity.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == CPTemplateApplicationSceneSessionRoleApplication {
            let configuration = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            #if canImport(CarPlayUI)
            configuration.delegateClass = CarPlaySceneDelegate.self
            #endif
            return configuration
        }

        return UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
    }
}
#endif
