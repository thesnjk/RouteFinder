#if os(iOS)
import CarPlay
import Contracts
import CoreLocation
import Foundation
import NavigationCore

/// Subscribes to `NavigationSession` and drives CarPlay templates.
@MainActor
public final class CarPlayNavigationCoordinator: NavigationSessionDelegate {
    public let mapTemplateController = CarPlayMapTemplateController()
    private let interfaceController: CPInterfaceController
    private let navigationSession: NavigationSession
    private let sessionAdapter = CarPlayNavigationSessionAdapter()
    private let alertPresenter: CarPlayAlertPresenter
    private var tripStarted = false
    private var invalidVehicleRetryHandler: (() -> Void)?
    private var invalidVehicleFallbackHandler: (() -> Void)?

    /// Creates a CarPlay navigation coordinator.
    public init(interfaceController: CPInterfaceController, navigationSession: NavigationSession) {
        self.interfaceController = interfaceController
        self.navigationSession = navigationSession
        self.alertPresenter = CarPlayAlertPresenter(interfaceController: interfaceController)
    }

    /// Tears down active CarPlay navigation state.
    public func teardown() {
        sessionAdapter.cancel()
        tripStarted = false
    }

    public func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        if !tripStarted {
            startTripIfPossible(progress: snapshot)
        }
        sessionAdapter.update(progress: snapshot)
    }

    public func navigationSession(_ session: NavigationSession, didAdvanceManeuver instruction: TurnInstruction) {
        sessionAdapter.updateManeuver(instruction)
    }

    public func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase) {
        if phase == .completed || phase == .idle {
            sessionAdapter.cancel()
            tripStarted = false
        }
    }

    public func navigationSession(_ session: NavigationSession, didEncounterInvalidVehicleProfile message: String) {
        alertPresenter.presentInvalidVehicleProfile(
            message: message,
            onRetry: { [weak self] in
                self?.interfaceController.dismissTemplate(animated: true) { _, _ in
                    self?.invalidVehicleRetryHandler?()
                }
            },
            onUseDefault: { [weak self] in
                self?.interfaceController.dismissTemplate(animated: true) { _, _ in
                    self?.invalidVehicleFallbackHandler?()
                }
            }
        )
    }

    /// Registers handlers invoked after the invalid vehicle profile alert is dismissed.
    public func configureInvalidVehicleHandlers(
        onRetry: @escaping () -> Void,
        onUseDefault: @escaping () -> Void
    ) {
        invalidVehicleRetryHandler = onRetry
        invalidVehicleFallbackHandler = onUseDefault
    }

    private func startTripIfPossible(progress: NavigationProgressSnapshot) {
        guard let geometry = navigationSession.canonicalGeometry,
              let origin = geometry.displayCoordinates.first,
              let destination = geometry.displayCoordinates.last else { return }

        let routeChoice = CarPlayTemplateFactory.makeRouteChoice(
            name: "Active Route",
            distanceMeters: progress.totalLengthMeters,
            timeSeconds: progress.remainingETASeconds
        )
        let trip = CarPlayTemplateFactory.makeTrip(
            origin: origin,
            destination: destination,
            routeChoices: [routeChoice]
        )
        sessionAdapter.start(
            mapTemplate: mapTemplateController.rootTemplate,
            trip: trip,
            routeChoice: routeChoice
        )
        tripStarted = true
    }
}
#endif
