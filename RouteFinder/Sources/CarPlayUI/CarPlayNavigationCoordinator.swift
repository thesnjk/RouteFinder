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

    /// Bootstraps an in-progress trip when CarPlay connects mid-navigation.
    public func bootstrapIfNeeded() {
        guard !tripStarted else { return }
        if let progress = navigationSession.progressSnapshot {
            startTripIfPossible(progress: progress)
            return
        }
        if navigationSession.phase == .navigating || navigationSession.canonicalGeometry != nil {
            let length = navigationSession.canonicalGeometry?.totalLengthMeters ?? 0
            let eta = navigationSession.staticTotalTimeSeconds
            let synthetic = NavigationProgressSnapshot(
                remainingDistanceMeters: length,
                remainingETASeconds: eta,
                traveledDistanceMeters: 0,
                progressFraction: 0,
                arcLengthMeters: 0,
                totalLengthMeters: length,
                currentManeuverIndex: 0
            )
            startTripIfPossible(progress: synthetic)
        }
    }

    public func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        if !tripStarted {
            startTripIfPossible(progress: snapshot)
        }
        sessionAdapter.update(progress: snapshot)
    }

    public func navigationSession(_ session: NavigationSession, didAdvanceManeuver instruction: TurnInstruction) {
        sessionAdapter.updateManeuver(instruction, progress: session.progressSnapshot)
    }

    public func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase) {
        switch phase {
        case .navigating:
            bootstrapIfNeeded()
        case .completed, .idle:
            sessionAdapter.cancel()
            tripStarted = false
        case .routeLoaded:
            // Fleet re-dispatch (or recalculate) while CarPlay is connected: replace the active trip.
            if tripStarted {
                sessionAdapter.cancel()
                tripStarted = false
            }
            bootstrapIfNeeded()
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

    /// Presents an advisory HOS rest / remaining-drive alert on CarPlay.
    /// - Note: The digital tachograph remains the legal record.
    public func presentHosAdvisory(summary: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        alertPresenter.presentHosAdvisory(
            title: "Hours advisory",
            message: trimmed
        )
    }

    private func startTripIfPossible(progress: NavigationProgressSnapshot) {
        guard let geometry = navigationSession.canonicalGeometry,
              let origin = geometry.displayCoordinates.first,
              let destination = geometry.displayCoordinates.last else { return }

        let labels = CarPlayServices.routeEndpointLabels?()
        let originName = nonEmptyLabel(labels?.origin) ?? "Origin"
        let destinationName = nonEmptyLabel(labels?.destination) ?? "Destination"
        let routeChoiceName = nonEmptyLabel(CarPlayServices.routeChoiceTitle?())
            ?? (labels != nil ? "\(originName) → \(destinationName)" : "Active Route")

        let routeChoice = CarPlayTemplateFactory.makeRouteChoice(
            name: routeChoiceName,
            distanceMeters: progress.remainingDistanceMeters > 0
                ? progress.remainingDistanceMeters
                : progress.totalLengthMeters,
            timeSeconds: progress.remainingETASeconds
        )
        let trip = CarPlayTemplateFactory.makeTrip(
            origin: origin,
            destination: destination,
            routeChoices: [routeChoice],
            originName: originName,
            destinationName: destinationName
        )
        let instruction = navigationSession.currentInstruction()
            ?? navigationSession.currentInstruction(atArcLength: 0)
        sessionAdapter.start(
            mapTemplate: mapTemplateController.rootTemplate,
            trip: trip,
            routeChoice: routeChoice,
            initialInstruction: instruction,
            progress: progress
        )
        tripStarted = true
    }

    private func nonEmptyLabel(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
#endif
