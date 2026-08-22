import Foundation

/// Identifies which velocity governor cap is currently binding simulation speed.
public enum VelocityCapReason: String, Sendable, Equatable {
    case legal
    case curve
    case cruise
    case signal
}
