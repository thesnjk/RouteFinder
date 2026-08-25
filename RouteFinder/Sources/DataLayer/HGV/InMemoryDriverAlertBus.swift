import Contracts
import Foundation

/// In-memory fan-out bus for driver-facing alerts (HOS, kinetic, parking, etc.).
public actor InMemoryDriverAlertBus: DriverAlertBusPort {
    private var alerts: [DriverAlert] = []
    private var continuations: [UUID: AsyncStream<DriverAlert>.Continuation] = [:]
    private let capacity: Int

    /// Creates an alert bus that retains the most recent alerts up to `capacity`.
    public init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    /// Publishes an alert to all subscribers and retains it in memory.
    public func publish(_ alert: DriverAlert) async {
        alerts.append(alert)
        if alerts.count > capacity {
            alerts.removeFirst(alerts.count - capacity)
        }
        for continuation in continuations.values {
            continuation.yield(alert)
        }
    }

    /// Returns retained alerts in chronological order.
    public func recentAlerts() -> [DriverAlert] {
        alerts
    }

    /// Subscribes to live alert publications.
    public func subscribe() -> AsyncStream<DriverAlert> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
