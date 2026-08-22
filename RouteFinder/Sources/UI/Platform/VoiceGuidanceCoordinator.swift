#if os(iOS)
import Contracts
import Foundation
import NavigationCore

/// Coordinates background-safe voice guidance from navigation session events.
@MainActor
public final class VoiceGuidanceCoordinator: NavigationSessionDelegate {
    private let voiceService = NavigationVoiceService()
    private let announcementController = ManeuverAnnouncementController()
    private weak var navigationSession: NavigationSession?
    private var isEnabled: Bool

    /// Creates a voice guidance coordinator.
    public init(isEnabled: Bool = NavigationWorkspaceSettings.loadVoiceGuidanceEnabled()) {
        self.isEnabled = isEnabled
    }

    /// Updates whether voice guidance is active.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        NavigationWorkspaceSettings.saveVoiceGuidanceEnabled(enabled)
        if !enabled {
            teardown()
        }
    }

    /// Attaches to a navigation session for delegate callbacks.
    public func attach(to session: NavigationSession) {
        navigationSession = session
    }

    /// Tears down voice guidance state.
    public func teardown() {
        voiceService.stop()
        voiceService.deactivateAudioSession()
        announcementController.reset()
    }

    public func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        evaluateDistanceTiers(session: session, snapshot: snapshot)
    }

    public func navigationSession(_ session: NavigationSession, didAdvanceManeuver instruction: TurnInstruction) {
        announcementController.advanceToManeuver(instructionID: instruction.id)
    }

    public func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase) {
        switch phase {
        case .navigating:
            guard isEnabled else { return }
            announcementController.reset()
            try? voiceService.configureAudioSession()
        case .completed, .idle:
            teardown()
        case .routeLoaded:
            break
        }
    }

    public func navigationSession(_ session: NavigationSession, didUpdatePosition update: NavigationPositionUpdate) {
        guard isEnabled, session.phase == .navigating else { return }

        let offRoute = update.source == .hardwareGPS
            && update.qualityIndicator == .stale
        announcementController.setOffRoute(offRoute)
    }

    private func evaluateDistanceTiers(
        session: NavigationSession,
        snapshot: NavigationProgressSnapshot
    ) {
        guard isEnabled, session.phase == .navigating,
              let catalog = session.maneuverAnchorCatalog,
              let distance = catalog.distanceToNextManeuver(from: snapshot.arcLengthMeters),
              let nextAnchor = catalog.nextAnchor(after: snapshot.arcLengthMeters) else { return }

        let instruction = TurnInstruction(
            id: nextAnchor.id,
            maneuver: nextAnchor.maneuver,
            roadName: nextAnchor.roadName,
            distance: distance,
            bearing: 0
        )

        for tier in AnnouncementTier.allCases.reversed() {
            guard announcementController.shouldAnnounce(
                instruction: instruction,
                tier: tier,
                distanceToManeuverMeters: distance,
                catalog: catalog,
                currentArcLength: snapshot.arcLengthMeters
            ) else { continue }

            let text = ManeuverSpeechFormatter.spokenPrompt(for: instruction, tier: tier)
            let prompt = SpeechPrompt(
                text: text,
                priority: tier.priority,
                tier: tier,
                instructionID: instruction.id
            )
            voiceService.speak(prompt)
            announcementController.recordSpoken(instructionID: instruction.id, tier: tier)

            if tier == .execute, instruction.maneuver == .arrive {
                announcementController.markRouteCompleted()
            }
            break
        }
    }
}
#endif
