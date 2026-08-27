import Contracts
import Foundation

/// In-memory fan-out hub for fleet dispatch SSE events per vehicle.
public actor FleetEventHub {
    private var subscribers: [UUID: [UUID: AsyncStream<FleetDispatchEvent>.Continuation]] = [:]
    /// Interval between heartbeat events on open SSE connections.
    public let heartbeatIntervalSeconds: TimeInterval

    /// Creates a fleet event hub.
    public init(heartbeatIntervalSeconds: TimeInterval = 15) {
        self.heartbeatIntervalSeconds = heartbeatIntervalSeconds
    }

    /// Subscribes to live dispatch events for a vehicle.
    public func events(for vehicleId: UUID) -> AsyncStream<FleetDispatchEvent> {
        let subscriberId = UUID()
        return AsyncStream { continuation in
            Task {
                await addSubscriber(vehicleId: vehicleId, id: subscriberId, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeSubscriber(vehicleId: vehicleId, id: subscriberId)
                }
            }
        }
    }

    /// Publishes an event to all subscribers for the event's vehicle.
    public func publish(_ event: FleetDispatchEvent) {
        guard let vehicleSubscribers = subscribers[event.vehicleId] else { return }
        for continuation in vehicleSubscribers.values {
            continuation.yield(event)
        }
    }

    private func addSubscriber(
        vehicleId: UUID,
        id: UUID,
        continuation: AsyncStream<FleetDispatchEvent>.Continuation
    ) async {
        subscribers[vehicleId, default: [:]][id] = continuation
    }

    private func removeSubscriber(vehicleId: UUID, id: UUID) {
        subscribers[vehicleId]?[id] = nil
        if subscribers[vehicleId]?.isEmpty == true {
            subscribers[vehicleId] = nil
        }
    }
}
