import Foundation

/// Persists fleet driver/dispatch workspace preferences (local MVP).
public enum FleetWorkspaceSettings {
    private static let fleetVehicleIdKey = "RouteFinder.fleetVehicleId"

    /// Loads the fleet vehicle UUID used for dispatch polling on the driver device.
    public static func loadFleetVehicleId(defaults: UserDefaults = .standard) -> UUID? {
        guard let raw = defaults.string(forKey: fleetVehicleIdKey) else { return nil }
        return UUID(uuidString: raw)
    }

    /// Persists the fleet vehicle UUID for driver dispatch polling.
    public static func saveFleetVehicleId(_ vehicleId: UUID, defaults: UserDefaults = .standard) {
        defaults.set(vehicleId.uuidString, forKey: fleetVehicleIdKey)
    }
}
