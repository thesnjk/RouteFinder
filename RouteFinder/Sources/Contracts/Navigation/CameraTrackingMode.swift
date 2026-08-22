import Foundation

/// Camera follow behavior for the navigation map viewport.
public enum CameraTrackingMode: String, Sendable, Equatable, Codable {
    /// User can pan and zoom freely; camera lock is released.
    case freePan
    /// Camera centers on the vehicle with north up.
    case lockNorth
    /// Camera centers on the vehicle and rotates to match movement bearing.
    case lockHeading
}
