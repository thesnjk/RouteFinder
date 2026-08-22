import Contracts
import Foundation

/// Receives navigation session updates from the headless navigation service.
@MainActor
public protocol NavigationSessionDelegate: AnyObject {
    /// Called when live progress metrics change.
    func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot)
    /// Called when a new position sample arrives.
    func navigationSession(_ session: NavigationSession, didUpdatePosition update: NavigationPositionUpdate)
    /// Called when the route polyline split changes.
    func navigationSession(_ session: NavigationSession, didUpdateRouteSplit split: RouteSplitResult)
    /// Called when the upcoming maneuver advances.
    func navigationSession(_ session: NavigationSession, didAdvanceManeuver instruction: TurnInstruction)
    /// Called when navigation phase changes.
    func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase)
    /// Called when vehicle registry lookup yields invalid parameters.
    func navigationSession(_ session: NavigationSession, didEncounterInvalidVehicleProfile message: String)
}

/// Default no-op implementations for optional delegate methods.
public extension NavigationSessionDelegate {
    func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {}
    func navigationSession(_ session: NavigationSession, didUpdatePosition update: NavigationPositionUpdate) {}
    func navigationSession(_ session: NavigationSession, didUpdateRouteSplit split: RouteSplitResult) {}
    func navigationSession(_ session: NavigationSession, didAdvanceManeuver instruction: TurnInstruction) {}
    func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase) {}
    func navigationSession(_ session: NavigationSession, didEncounterInvalidVehicleProfile message: String) {}
}
