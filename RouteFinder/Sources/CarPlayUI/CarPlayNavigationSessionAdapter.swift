#if os(iOS)
import CarPlay
import Contracts
import Foundation
import MapKit

/// Bridges `NavigationSession` progress to `CPNavigationSession` travel estimates.
@MainActor
public final class CarPlayNavigationSessionAdapter {
    private var navigationSession: CPNavigationSession?
    private var currentManeuver: CPManeuver?

    /// Whether an active CarPlay navigation session exists.
    public var isActive: Bool { navigationSession != nil }

    /// Starts a CarPlay navigation session for the given trip on the root map template.
    public func start(
        mapTemplate: CPMapTemplate,
        trip: CPTrip,
        routeChoice: CPRouteChoice
    ) {
        navigationSession = mapTemplate.startNavigationSession(for: trip)
    }

    /// Updates travel estimates from a navigation progress snapshot.
    public func update(progress: NavigationProgressSnapshot) {
        guard let navigationSession, let currentManeuver else { return }
        let estimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: progress.remainingDistanceMeters, unit: .meters),
            timeRemaining: progress.remainingETASeconds
        )
        navigationSession.updateEstimates(estimates, for: currentManeuver)
    }

    /// Updates the active maneuver on the CarPlay navigation session.
    public func updateManeuver(_ instruction: TurnInstruction) {
        guard let navigationSession else { return }
        let maneuver = CarPlayTemplateFactory.makeManeuver(from: instruction)
        currentManeuver = maneuver
        navigationSession.upcomingManeuvers = [maneuver]
    }

    /// Cancels the active navigation session.
    public func cancel() {
        navigationSession?.cancelTrip()
        navigationSession = nil
        currentManeuver = nil
    }
}
#endif
