import Contracts
import Foundation

/// Selects local disk or remote HTTP fleet storage based on workspace settings.
public enum FleetStoreFactory {
    /// Creates the active fleet dispatch store for this device.
    public static func makeStore(defaults: UserDefaults = .standard) -> any FleetDispatchPort {
        if FleetWorkspaceSettings.useRemoteFleetServer(defaults: defaults),
           let url = FleetWorkspaceSettings.loadFleetServerURL(defaults: defaults) {
            return HTTPFleetStore(baseURL: url)
        }
        return DiskFleetStore()
    }
}
