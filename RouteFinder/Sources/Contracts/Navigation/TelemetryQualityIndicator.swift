import Foundation

/// Signals the reliability of a telemetry sample from simulation or fused hardware sensors.
public enum TelemetryQualityIndicator: String, Sendable, Equatable, Codable {
    /// Sample sourced directly from GPS or simulation physics.
    case live
    /// Position extrapolated during brief GPS dropout using motion fusion.
    case deadReckoning
    /// Extrapolation expired; holding last known position.
    case stale
}
