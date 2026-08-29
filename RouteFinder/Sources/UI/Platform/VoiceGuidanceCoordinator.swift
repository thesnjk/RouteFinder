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

    /// Speaks a kinetic advisory (brake fade, grade, slip) during live or simulated navigation.
    public func speakKineticAdvisory(_ advisory: KineticAdvisory) {
        guard isEnabled else { return }
        let prompt = SpeechPrompt(
            text: advisory.spokenText,
            priority: max(advisory.priority, AnnouncementTier.execute.priority),
            tier: .execute,
            instructionID: advisory.id
        )
        voiceService.speak(prompt)
    }

    /// Speaks an upcoming layby advisory when layby voice alerts are enabled.
    public func speakLaybyAdvisory(_ text: String, laybyId: String) {
        let prompt = SpeechPrompt(
            text: text,
            priority: AnnouncementTier.prepare.priority,
            tier: .prepare,
            instructionID: stableInstructionID(namespace: "layby", value: laybyId)
        )
        voiceService.speak(prompt)
    }

    /// Speaks an upcoming closure/traffic hazard when hazard voice alerts are enabled.
    public func speakHazardAdvisory(_ text: String, hazardId: String) {
        let prompt = SpeechPrompt(
            text: text,
            priority: AnnouncementTier.prepare.priority,
            tier: .prepare,
            instructionID: stableInstructionID(namespace: "hazard", value: hazardId)
        )
        voiceService.speak(prompt)
    }

    private func stableInstructionID(namespace: String, value: String) -> UUID {
        if let uuid = UUID(uuidString: value) {
            return uuid
        }
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        let seed = "\(namespace):\(value)"
        for (offset, byte) in seed.utf8.enumerated() {
            uuidBytes[offset % 16] &+= byte
        }
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    private func evaluateDistanceTiers(
        session: NavigationSession,
        snapshot: NavigationProgressSnapshot
    ) {
        guard isEnabled, session.phase == .navigating,
              let catalog = session.maneuverAnchorCatalog,
              let distance = catalog.distanceToNextManeuver(from: snapshot.arcLengthMeters),
              let nextAnchor = catalog.nextAnchor(after: snapshot.arcLengthMeters) else { return }

        let instruction = resolvedInstruction(
            session: session,
            nextAnchor: nextAnchor,
            distanceToManeuverMeters: distance
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

    private func resolvedInstruction(
        session: NavigationSession,
        nextAnchor: ManeuverAnchor,
        distanceToManeuverMeters: Double
    ) -> TurnInstruction {
        if let stored = session.turnInstruction(withID: nextAnchor.id) {
            return TurnInstruction(
                id: stored.id,
                maneuver: stored.maneuver,
                roadName: stored.roadName,
                distance: distanceToManeuverMeters,
                bearing: stored.bearing,
                recommendedSpeedKmh: stored.recommendedSpeedKmh,
                laneGuidance: stored.laneGuidance
            )
        }
        return TurnInstruction(
            id: nextAnchor.id,
            maneuver: nextAnchor.maneuver,
            roadName: nextAnchor.roadName,
            distance: distanceToManeuverMeters,
            bearing: 0
        )
    }
}
#endif
