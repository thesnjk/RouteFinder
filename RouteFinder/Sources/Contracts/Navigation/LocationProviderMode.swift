import Foundation

/// Identifies the active position source for navigation tracking.
public enum LocationProviderMode: String, Sendable, Equatable, Codable {
    /// Synthetic physics-based route simulation.
    case simulation
    /// Device hardware GPS via CoreLocation.
    case hardwareGPS
}
