import Foundation

/// Whether the desk may push a trip to a paired driver (LAN / hosted fleet).
///
/// Requires a remote Connected health pill — Local disk / Offline / Auth failed must not
/// produce a fake “Dispatched…” toast while cabs on SSE never receive the trip.
public enum DispatchPushGate: Sendable {
    /// True when push has a vehicle, ≥2 resolved stops, remote fleet, and Connected health.
    public static func canPush(
        hasVehicle: Bool,
        hasResolvedStops: Bool,
        isRemoteFleet: Bool,
        healthOk: Bool
    ) -> Bool {
        hasVehicle && hasResolvedStops && isRemoteFleet && healthOk
    }

    /// True when draft is otherwise ready but fleet health/remote blocks push.
    public static func isBlockedByFleetHealth(
        hasVehicle: Bool,
        hasResolvedStops: Bool,
        isRemoteFleet: Bool,
        healthOk: Bool
    ) -> Bool {
        hasVehicle && hasResolvedStops && !(isRemoteFleet && healthOk)
    }
}
