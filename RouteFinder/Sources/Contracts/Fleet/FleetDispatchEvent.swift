import Foundation

/// Kind of fleet dispatch event streamed to driver devices.
public enum FleetDispatchEventKind: String, Sendable, Codable {
    /// A new trip was pushed to the subscribed vehicle.
    case tripPushed
    /// Keep-alive ping so clients detect dead connections.
    case heartbeat
}

/// Server-sent event published when fleet dispatch state changes for a vehicle.
public struct FleetDispatchEvent: Sendable, Codable, Equatable {
    /// Event classification.
    public let kind: FleetDispatchEventKind
    /// Vehicle the event applies to.
    public let vehicleId: UUID
    /// Trip id when `kind` is `tripPushed`.
    public let tripId: UUID?
    /// UTC timestamp when the event was emitted.
    public let timestamp: Date

    /// Creates a fleet dispatch SSE event.
    public init(kind: FleetDispatchEventKind, vehicleId: UUID, tripId: UUID?, timestamp: Date) {
        self.kind = kind
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.timestamp = timestamp
    }
}
