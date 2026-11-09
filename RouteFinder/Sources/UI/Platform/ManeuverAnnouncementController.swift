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

    /// Clears a spoken prepare so OSM-upgraded lane guidance can re-speak inside the prepare window.
    ///
    /// No-ops when execute was already spoken for this maneuver. Does not reopen approach.
    public func invalidatePrepareForLaneUpgrade(instructionID: UUID) {
        let spoken = spokenTiers[instructionID, default: []]
        guard spoken.contains(.prepare) else { return }
        guard !spoken.contains(.execute) else { return }

        spokenTiers[instructionID]?.remove(.prepare)
        if let key = refireKey(instructionID: instructionID, tier: .prepare) {
            lastTierSpokenAt.removeValue(forKey: key)
        }
    }

    /// Instruction IDs whose lane guidance upgraded from non-OSM (or nil) to OSM.
    public nonisolated static func instructionIDsUpgradedToOSM(
        previous: [TurnInstruction],
        updated: [TurnInstruction]
    ) -> [UUID] {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        return updated.compactMap { instruction in
            guard instruction.laneGuidance?.source == .osm else { return nil }
            let priorSource = previousByID[instruction.id]?.laneGuidance?.source
            guard priorSource != .osm else { return nil }
            return instruction.id
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
