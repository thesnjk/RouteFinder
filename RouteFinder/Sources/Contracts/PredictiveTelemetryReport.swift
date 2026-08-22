import Foundation

/// Type of simulation telemetry event recorded during route playback.
public enum SimulationEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    /// High-energy deceleration event (traffic signal or hard braking).
    case hardDeceleration
    /// Sustained thermal brake fade period.
    case brakeFade
    /// Lateral G-force violation on a curve.
    case lateralGViolation
    /// Tire slip angle threshold exceeded.
    case tireSlip
}

/// A timestamped simulation telemetry event.
public struct SimulationEvent: Codable, Equatable, Sendable, Hashable, Identifiable {
    /// Unique event identifier.
    public let id: UUID
    /// Event classification.
    public let kind: SimulationEventKind
    /// Arc length along route when event occurred in meters.
    public let arcLengthMeters: Double
    /// Simulation elapsed time in seconds.
    public let elapsedSeconds: TimeInterval
    /// Event magnitude (decel m/s², slip angle degrees, lateral G fraction, thermal J).
    public let magnitude: Double

    /// Creates a simulation telemetry event.
    public init(
        id: UUID = UUID(),
        kind: SimulationEventKind,
        arcLengthMeters: Double,
        elapsedSeconds: TimeInterval,
        magnitude: Double
    ) {
        self.id = id
        self.kind = kind
        self.arcLengthMeters = arcLengthMeters
        self.elapsedSeconds = elapsedSeconds
        self.magnitude = magnitude
    }
}

/// Post-route predictive telemetry report comparing kinetic vs static ETA.
public struct PredictiveTelemetryReport: Codable, Equatable, Sendable, Hashable {
    /// Static web routing ETA in seconds (ORS baseline).
    public let staticWebETASeconds: TimeInterval
    /// Kinetic physics simulation ETA in seconds.
    public let kineticPhysicsETASeconds: TimeInterval
    /// Brake Wear & Kinetic Fleet Efficiency Index (0–100).
    public let brakeWearKineticEfficiencyIndex: Double
    /// Estimated annual insurance premium savings in GBP.
    public let estimatedPremiumSavingsGBP: Decimal
    /// Count of hard deceleration events.
    public let hardDecelEventCount: Int
    /// Count of brake fade risk periods.
    public let brakeFadeRiskEventCount: Int
    /// Count of lateral G violations.
    public let lateralGViolationCount: Int
    /// Count of tire slip events.
    public let tireSlipEventCount: Int
    /// Peak brake fade risk state observed during route.
    public let brakeFadeRiskState: BrakeFadeRisk?
    /// All recorded simulation events.
    public let events: [SimulationEvent]

    /// Creates a predictive telemetry report.
    public init(
        staticWebETASeconds: TimeInterval,
        kineticPhysicsETASeconds: TimeInterval,
        brakeWearKineticEfficiencyIndex: Double,
        estimatedPremiumSavingsGBP: Decimal,
        hardDecelEventCount: Int,
        brakeFadeRiskEventCount: Int,
        lateralGViolationCount: Int,
        tireSlipEventCount: Int,
        brakeFadeRiskState: BrakeFadeRisk?,
        events: [SimulationEvent]
    ) {
        self.staticWebETASeconds = staticWebETASeconds
        self.kineticPhysicsETASeconds = kineticPhysicsETASeconds
        self.brakeWearKineticEfficiencyIndex = brakeWearKineticEfficiencyIndex
        self.estimatedPremiumSavingsGBP = estimatedPremiumSavingsGBP
        self.hardDecelEventCount = hardDecelEventCount
        self.brakeFadeRiskEventCount = brakeFadeRiskEventCount
        self.lateralGViolationCount = lateralGViolationCount
        self.tireSlipEventCount = tireSlipEventCount
        self.brakeFadeRiskState = brakeFadeRiskState
        self.events = events
    }
}
