import Contracts
import Foundation

/// Result of a headless kinetic physics duration estimate.
public struct PhysicsRouteDurationResult: Sendable, Equatable {
    /// Predicted route duration from the physics integrator (seconds).
    public let kineticDurationSeconds: TimeInterval
    /// Static web-routing ETA used as the comparison baseline (seconds).
    public let staticWebETASeconds: TimeInterval

    /// Creates a physics duration result.
    public init(kineticDurationSeconds: TimeInterval, staticWebETASeconds: TimeInterval = 0) {
        self.kineticDurationSeconds = kineticDurationSeconds
        self.staticWebETASeconds = staticWebETASeconds
    }
}

/// Runs a headless physics integration pass to predict kinetic route duration.
public enum PhysicsRouteDurationEstimator {
    /// Default wall-clock budget for headless estimation.
    public static let defaultTimeoutSeconds: TimeInterval = 12

    /// Estimates kinetic duration for a configured route.
    public static func estimate(
        configuration: SimulationPhysicsConfiguration,
        tomTomAPIKey: String? = nil,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds
    ) async -> PhysicsRouteDurationResult? {
        guard let report = await RouteRehearsalService.rehearse(
            configuration: configuration,
            tomTomAPIKey: tomTomAPIKey,
            timeoutSeconds: timeoutSeconds
        ) else {
            return nil
        }
        return PhysicsRouteDurationResult(
            kineticDurationSeconds: report.kineticPhysicsETASeconds,
            staticWebETASeconds: report.staticWebETASeconds
        )
    }
}
