import Foundation

/// Holds a NotificationCenter observer token and removes it on deallocation.
final class FleetStoreConfigurationObserver: @unchecked Sendable {
    var token: NSObjectProtocol?

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
