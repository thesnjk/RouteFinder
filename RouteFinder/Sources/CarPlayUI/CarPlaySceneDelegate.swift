#if os(iOS)
import CarPlay
import Contracts
import Foundation
import NavigationCore
import UIKit

/// Shared navigation session injected at application launch for CarPlay connectivity.
@MainActor
public enum CarPlayServices {
    /// Navigation session shared between phone UI and CarPlay.
    public static weak var navigationSession: NavigationSession?
    /// Optional hook to register CarPlay as a session delegate at connect time.
    public static var registerDelegate: ((NavigationSessionDelegate) -> Void)?
}

/// CarPlay template application scene delegate hosting the map navigation UI.
@MainActor
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var coordinator: CarPlayNavigationCoordinator?
    private weak var connectedSession: NavigationSession?

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        guard let session = CarPlayServices.navigationSession ?? NavigationSessionRegistry.shared else { return }
        connectedSession = session
        let coordinator = CarPlayNavigationCoordinator(
            interfaceController: interfaceController,
            navigationSession: session
        )
        self.coordinator = coordinator
        CarPlayServices.registerDelegate?(coordinator)
        session.addDelegate(coordinator)
        Task { @MainActor in
            try? await interfaceController.setRootTemplate(
                coordinator.mapTemplateController.rootTemplate,
                animated: true
            )
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController,
        from window: UIWindow
    ) {
        _ = templateApplicationScene
        _ = interfaceController
        _ = window
        if let coordinator, let connectedSession {
            connectedSession.removeDelegate(coordinator)
        }
        coordinator?.teardown()
        coordinator = nil
        connectedSession = nil
        self.interfaceController = nil
    }
}
#endif
