#if os(iOS)
import Contracts
import Foundation

/// Enforces boundary rules for multi-tier maneuver voice announcements.
@MainActor
public final class ManeuverAnnouncementController {
    private var spokenTiers: [UUID: Set<AnnouncementTier>] = [:]
    private var lastTierSpokenAt: [String: Date] = [:]
    private var pendingExecuteForManeuverID: UUID?
    private var routeCompleted = false
    private var isOffRoute = false

    private let minimumInterManeuverSpacingMeters = 200.0
    private let minimumRefireIntervalSeconds: TimeInterval = 60

    public init() {}

    /// Resets all announcement state for a new route or navigation session.
    public func reset() {
        spokenTiers.removeAll()
        lastTierSpokenAt.removeAll()
        pendingExecuteForManeuverID = nil
        routeCompleted = false
        isOffRoute = false
    }

    /// Marks navigation as off-route, pausing tier evaluation.
    public func setOffRoute(_ offRoute: Bool) {
        isOffRoute = offRoute
    }

    /// Evaluates whether a tier should fire for the given maneuver context.
    public func shouldAnnounce(
        instruction: TurnInstruction,
        tier: AnnouncementTier,
        distanceToManeuverMeters: Double,
        catalog: ManeuverAnchorCatalog,
        currentArcLength: Double
    ) -> Bool {
        guard !routeCompleted, !isOffRoute else { return false }
        guard distanceToManeuverMeters <= tier.thresholdMeters else { return false }

        if ManeuverSpeechFormatter.shouldSuppressVoice(maneuver: instruction.maneuver, tier: tier) {
            return false
        }

        let spoken = spokenTiers[instruction.id, default: []]
        if spoken.contains(tier) { return false }

        if let refireKey = refireKey(instructionID: instruction.id, tier: tier),
           let lastSpoken = lastTierSpokenAt[refireKey],
           Date().timeIntervalSince(lastSpoken) < minimumRefireIntervalSeconds {
            return false
        }

        if tier == .approach {
            if shouldSuppressApproach(for: instruction, catalog: catalog, currentArcLength: currentArcLength) {
                return false
            }
        }

        if !tierMonotonicityAllows(spoken: spoken, candidate: tier) {
            return false
        }

        return true
    }

    /// Records that a tier was spoken for an instruction.
    public func recordSpoken(instructionID: UUID, tier: AnnouncementTier) {
        spokenTiers[instructionID, default: []].insert(tier)
        lastTierSpokenAt[refireKey(instructionID: instructionID, tier: tier) ?? ""] = Date()

        if tier == .execute {
            pendingExecuteForManeuverID = instructionID
        }
    }

    /// Resets tier flags when advancing to a new maneuver.
    public func advanceToManeuver(instructionID: UUID) {
        pendingExecuteForManeuverID = nil
        if spokenTiers[instructionID] == nil {
            spokenTiers[instructionID] = []
        }
    }

    /// Marks route completion after arrive execute prompt.
    public func markRouteCompleted() {
        routeCompleted = true
    }

    private func tierMonotonicityAllows(spoken: Set<AnnouncementTier>, candidate: AnnouncementTier) -> Bool {
        if spoken.contains(.execute) { return false }
        if candidate == .approach, spoken.contains(.prepare) || spoken.contains(.execute) { return false }
        if candidate == .prepare, spoken.contains(.execute) { return false }
        return true
    }

    private func shouldSuppressApproach(
        for instruction: TurnInstruction,
        catalog: ManeuverAnchorCatalog,
        currentArcLength: Double
    ) -> Bool {
        guard let currentAnchor = catalog.anchor(for: instruction.id),
              let currentIndex = catalog.anchors.firstIndex(where: { $0.id == instruction.id }),
              currentIndex > 0 else { return false }

        let previous = catalog.anchors[currentIndex - 1]
        let spacing = currentAnchor.arcLengthAnchor - previous.arcLengthAnchor
        guard spacing < minimumInterManeuverSpacingMeters else { return false }

        if let pending = pendingExecuteForManeuverID, pending == previous.id {
            return true
        }

        let previousSpoken = spokenTiers[previous.id, default: []]
        return !previousSpoken.contains(.execute)
    }

    private func refireKey(instructionID: UUID, tier: AnnouncementTier) -> String? {
        "\(instructionID.uuidString)-\(tier.rawValue)"
    }
}
#endif
