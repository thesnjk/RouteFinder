#if os(iOS)
import CarPlay
import Contracts
import Foundation
import NavigationCore
import UIKit

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
        CarPlayServices.onSessionAvailable = { [weak self] in
            self?.attachSessionIfNeeded()
        }
        attachSessionIfNeeded()
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
        CarPlayServices.onSessionAvailable = nil
    }

    private func attachSessionIfNeeded() {
        guard let interfaceController else { return }
        guard let session = CarPlayServices.navigationSession ?? NavigationSessionRegistry.shared else {
            Task { @MainActor in
                try? await interfaceController.setRootTemplate(CPMapTemplate(), animated: true)
            }
            return
        }
        guard connectedSession !== session else {
            coordinator?.bootstrapIfNeeded()
            return
        }

        if let coordinator, let connectedSession {
            connectedSession.removeDelegate(coordinator)
            coordinator.teardown()
        }

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
            coordinator.bootstrapIfNeeded()
        }
    }
}
#endif
