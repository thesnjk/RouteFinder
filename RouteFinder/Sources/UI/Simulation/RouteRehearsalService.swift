import Contracts
import Foundation

/// Headless route rehearsal that produces a full predictive telemetry report before departure.
public enum RouteRehearsalService {
    private static let physicsStepSeconds = 1.0 / 60.0
    private static let headlessSpeedMultiplier = 100.0
    private static let maxSteps = 2_000_000
    public static let defaultTimeoutSeconds: TimeInterval = 20

    /// Rehearses a configured route and returns the predictive telematics report.
    public static func rehearse(
        configuration: SimulationPhysicsConfiguration,
        tomTomAPIKey: String? = nil,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds
    ) async -> PredictiveTelemetryReport? {
        guard configuration.totalRouteLength > 0 else { return nil }

        let mailbox = SimulationStateMailbox()
        let actor = SimulationPhysicsActor(tomTomAPIKey: tomTomAPIKey, mailbox: mailbox)
        await actor.configure(configuration)
        await actor.start()

        let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
        var steps = 0
        while steps < maxSteps {
            if Task.isCancelled { return nil }
            if ContinuousClock.now >= deadline { return nil }

            if let completion = await actor.step(
                fixedDeltaTime: physicsStepSeconds,
                simulationSpeedMultiplier: headlessSpeedMultiplier
            ) {
                return completion.telemetryReport
            }
            steps += 1
            if steps.isMultiple(of: 2_000) {
                await Task.yield()
            }
        }
        return nil
    }
}
