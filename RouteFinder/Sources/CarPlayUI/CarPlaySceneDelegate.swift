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
<<<<<<< HEAD
        NotificationCenter.default.addObserver(
            forName: .routeFinderHosAdvisory,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let summary = (note.userInfo?["summary"] as? String) ?? ""
            Task { @MainActor in
                self?.coordinator?.presentHosAdvisory(summary: summary)
            }
        }
=======
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
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
