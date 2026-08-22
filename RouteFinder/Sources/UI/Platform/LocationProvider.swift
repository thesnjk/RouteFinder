import Contracts
import CoreLocation
import Foundation

/// Delegate receiving position updates from a location provider.
@MainActor
public protocol LocationProviderDelegate: AnyObject {
    /// Called when a new position sample is available.
    func locationProvider(_ provider: any LocationProvider, didReceive update: NavigationPositionUpdate)
    #if os(iOS)
    /// Called when authorization status changes.
    func locationProvider(_ provider: any LocationProvider, didChangeAuthorization status: CLAuthorizationStatus)
    #endif
    /// Called when location updates fail.
    func locationProvider(_ provider: any LocationProvider, didFailWithError error: Error)
}

/// Abstracts position ingestion from simulation or hardware GPS.
@MainActor
public protocol LocationProvider: AnyObject {
    /// Active operational mode.
    var mode: LocationProviderMode { get }
    /// Whether the provider is actively emitting updates.
    var isActive: Bool { get }
    /// Maximum horizontal accuracy to accept GPS samples.
    var accuracyThresholdMeters: Double { get set }

    /// Starts emitting position updates.
    func start() async throws
    /// Stops emitting position updates.
    func stop()
    /// Sets the delegate for position callbacks.
    func setDelegate(_ delegate: LocationProviderDelegate?)
}

#if os(iOS)
import CoreLocation

extension CLAuthorizationStatus: @retroactive @unchecked Sendable {}
#endif
