import Contracts
import Foundation

/// Selects local disk or remote HTTP fleet storage based on workspace settings.
public enum FleetStoreFactory {
    /// Creates the active fleet dispatch store for this device.
    public static func makeStore() -> any FleetDispatchPort {
        if FleetWorkspaceSettings.useRemoteFleetServer(),
           let url = FleetWorkspaceSettings.loadFleetServerURL() {
            return HTTPFleetStore(baseURL: url)
        }
        return DiskFleetStore()
    }
}
