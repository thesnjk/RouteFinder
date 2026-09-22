import Contracts
import Foundation

/// Fuses hazard / weather / kinetic / roadworks / traffic signals into unified route-risk advisories.
@MainActor
public final class PredictiveRiskCoordinator {
    private let provider: any PredictiveRiskProviding
    /// Latest fused advisories (ordered by severity then distance).
    public private(set) var advisories: [RouteRiskAdvisory] = []
    /// Primary advisory for HUD / voice.
    public private(set) var primaryAdvisory: RouteRiskAdvisory?
    private var lastSpokenId: String?

    /// Creates a coordinator with the default fuse provider.
    public init(provider: (any PredictiveRiskProviding)? = nil) {
        self.provider = provider ?? DefaultPredictiveRiskProvider()
    }

    /// Rebuilds advisories from a live snapshot of existing navigation signals.
    public func refresh(snapshot: PredictiveRiskSnapshot) async {
        let fused = await provider.advisories(for: snapshot)
        advisories = fused.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.distanceRemainingMeters < rhs.distanceRemainingMeters
        }
        primaryAdvisory = RouteRiskFormatter.primaryAhead(advisories: advisories)
    }

    /// Returns a spoken prompt when the primary advisory changes.
    public func consumeSpokenPromptIfNeeded() -> String? {
        guard let primary = primaryAdvisory else { return nil }
        guard primary.id != lastSpokenId else { return nil }
        lastSpokenId = primary.id
        return RouteRiskFormatter.spokenPrompt(for: primary)
    }

    /// Clears advisories when navigation ends.
    public func reset() {
        advisories = []
        primaryAdvisory = nil
        lastSpokenId = nil
    }
}
