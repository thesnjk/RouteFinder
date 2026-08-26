import Foundation

extension Notification.Name {
    /// Posted when remote fleet server settings change and stores should reload.
    public static let fleetStoreConfigurationDidChange = Notification.Name(
        "RouteFinder.fleetStoreConfigurationDidChange"
    )
}

/// Persists fleet driver/dispatch workspace preferences (local MVP).
public enum FleetWorkspaceSettings {
    private static let fleetVehicleIdKey = "RouteFinder.fleetVehicleId"
    private static let fleetServerURLKey = "RouteFinder.fleetServerURL"
    private static let useRemoteFleetServerKey = "RouteFinder.useRemoteFleetServer"

    /// Loads the fleet vehicle UUID used for dispatch polling on the driver device.
    public static func loadFleetVehicleId(defaults: UserDefaults = .standard) -> UUID? {
        guard let raw = defaults.string(forKey: fleetVehicleIdKey) else { return nil }
        return UUID(uuidString: raw)
    }

    /// Persists the fleet vehicle UUID for driver dispatch polling.
    public static func saveFleetVehicleId(_ vehicleId: UUID, defaults: UserDefaults = .standard) {
        defaults.set(vehicleId.uuidString, forKey: fleetVehicleIdKey)
    }

    /// Whether the app should use a remote fleet HTTP server instead of local disk store.
    public static func useRemoteFleetServer(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: useRemoteFleetServerKey)
    }

    /// Persists the remote fleet server preference.
    public static func saveUseRemoteFleetServer(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: useRemoteFleetServerKey)
        postConfigurationDidChange()
    }

    /// Loads the base URL for the fleet HTTP server (e.g. `http://192.168.1.10:8080`).
    public static func loadFleetServerURL(defaults: UserDefaults = .standard) -> URL? {
        guard let raw = defaults.string(forKey: fleetServerURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    /// Persists the fleet HTTP server base URL.
    public static func saveFleetServerURL(_ url: URL?, defaults: UserDefaults = .standard) {
        if let url {
            defaults.set(url.absoluteString, forKey: fleetServerURLKey)
        } else {
            defaults.removeObject(forKey: fleetServerURLKey)
        }
        postConfigurationDidChange()
    }

    /// Persists remote fleet configuration and posts a single reload notification.
    public static func saveRemoteFleetConfiguration(
        useRemote: Bool,
        serverURL: URL?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(useRemote, forKey: useRemoteFleetServerKey)
        if let serverURL {
            defaults.set(serverURL.absoluteString, forKey: fleetServerURLKey)
        } else {
            defaults.removeObject(forKey: fleetServerURLKey)
        }
        postConfigurationDidChange()
    }

    private static func postConfigurationDidChange() {
        NotificationCenter.default.post(name: .fleetStoreConfigurationDidChange, object: nil)
    }
}
