import Contracts
import Foundation

/// Live kinetic advisory for navigation voice and HUD.
public struct KineticAdvisory: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Equatable {
        case brakeFade
        case steepGrade
        case tireSlip
        case hardDeceleration
    }

    public let id: UUID
    public let kind: Kind
    public let spokenText: String
    public let priority: Int
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        spokenText: String,
        priority: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.spokenText = spokenText
        self.priority = priority
        self.timestamp = timestamp
    }
}

/// Publishes kinetic advisories from simulation UI state for voice and HUD consumers.
@MainActor
public final class KineticAdvisoryCoordinator {
    public private(set) var latestAdvisory: KineticAdvisory?
    public var onAdvisory: ((KineticAdvisory) -> Void)?

    private var lastSpokenKind: KineticAdvisory.Kind?
    private var lastSpokenAt: Date?
    private let minimumInterval: TimeInterval = 45

    public init() {}

    /// Evaluates simulation UI state and emits advisories when thresholds are crossed.
    public func ingest(uiState: SimulationUIState) {
        if let fade = uiState.brakeFadeRisk {
            emitIfAllowed(
                KineticAdvisory(
                    kind: .brakeFade,
                    spokenText: spokenFade(fade),
                    priority: 4
                )
            )
            return
        }

        if let stress = uiState.currentKineticStress, abs(stress.gradePercentage) >= 6 {
            let downhill = stress.gradePercentage < 0
            emitIfAllowed(
                KineticAdvisory(
                    kind: .steepGrade,
                    spokenText: downhill
                        ? "Steep descent ahead. Manage speed and prepare for brake fade."
                        : "Steep climb ahead. Expect reduced speed under load.",
                    priority: 2
                )
            )
            return
        }

        if let topography = uiState.topographyState {
            let gradePercent = tan(topography.gradeAngleDegrees * .pi / 180) * 100
            if abs(gradePercent) >= 6 {
                let downhill = gradePercent < 0
                emitIfAllowed(
                    KineticAdvisory(
                        kind: .steepGrade,
                        spokenText: downhill
                            ? "Steep descent ahead. Manage speed and prepare for brake fade."
                            : "Steep climb ahead. Expect reduced speed under load.",
                        priority: 2
                    )
                )
            }
        }
    }

    /// Ingests a discrete simulation telemetry event during live playback.
    public func ingest(event: SimulationEvent) {
        switch event.kind {
        case .tireSlip:
            emitIfAllowed(
                KineticAdvisory(
                    kind: .tireSlip,
                    spokenText: "Tire slip risk. Reduce speed.",
                    priority: 3
                )
            )
        case .hardDeceleration:
            emitIfAllowed(
                KineticAdvisory(
                    kind: .hardDeceleration,
                    spokenText: "Hard braking detected. Increase following distance.",
                    priority: 3
                )
            )
        case .brakeFade:
            emitIfAllowed(
                KineticAdvisory(
                    kind: .brakeFade,
                    spokenText: "Brake fade risk rising. Use engine braking.",
                    priority: 4
                )
            )
        case .lateralGViolation:
            emitIfAllowed(
                KineticAdvisory(
                    kind: .tireSlip,
                    spokenText: "High lateral load. Slow for the curve.",
                    priority: 3
                )
            )
        }
    }

    public func reset() {
        latestAdvisory = nil
        lastSpokenKind = nil
        lastSpokenAt = nil
    }

    private func emitIfAllowed(_ advisory: KineticAdvisory) {
        if let lastSpokenKind, lastSpokenKind == advisory.kind,
           let lastSpokenAt,
           Date().timeIntervalSince(lastSpokenAt) < minimumInterval {
            return
        }
        latestAdvisory = advisory
        lastSpokenKind = advisory.kind
        lastSpokenAt = advisory.timestamp
        onAdvisory?(advisory)
    }

    private func spokenFade(_ fade: BrakeFadeRisk) -> String {
        switch fade {
        case .elevated:
            return "Elevated brake fade risk. Reduce speed on descent."
        case .critical:
            return "Critical brake fade risk. Stop safely and cool brakes."
        }
    }
}
