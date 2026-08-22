import Foundation

/// Congestion classification derived from live traffic flow ratios.
public enum TrafficCongestionLevel: String, Codable, Sendable, Hashable, CaseIterable {
    /// Unrestricted flow (multiplier 1.0).
    case freeFlow
    /// Light congestion (multiplier 0.8).
    case light
    /// Heavy congestion (multiplier 0.4).
    case heavy
    /// Standstill or near-standstill (multiplier 0.05).
    case standstill

    /// Velocity scaling multiplier applied to target speed.
    public var velocityMultiplier: Double {
        switch self {
        case .freeFlow: return 1.0
        case .light: return 0.8
        case .heavy: return 0.4
        case .standstill: return 0.05
        }
    }

    /// Classifies congestion from current speed vs free-flow speed ratio.
    public static func classify(currentSpeedKmh: Double, freeFlowSpeedKmh: Double) -> TrafficCongestionLevel {
        guard freeFlowSpeedKmh > 1 else { return .freeFlow }
        let ratio = currentSpeedKmh / freeFlowSpeedKmh
        if ratio >= 0.85 { return .freeFlow }
        if ratio >= 0.55 { return .light }
        if ratio >= 0.20 { return .heavy }
        return .standstill
    }
}

/// A traffic segment snapshot with congestion data mapped to route arc length.
public struct TrafficSegmentSnapshot: Codable, Equatable, Sendable, Hashable, Identifiable {
    /// Unique segment identifier.
    public let id: UUID
    /// Start arc length along route in meters.
    public let startArcLengthMeters: Double
    /// End arc length along route in meters.
    public let endArcLengthMeters: Double
    /// Congestion classification.
    public let congestionLevel: TrafficCongestionLevel
    /// Current observed speed in km/h.
    public let currentSpeedKmh: Double
    /// Free-flow speed in km/h.
    public let freeFlowSpeedKmh: Double
    /// Sample coordinate for spatial eviction.
    public let sampleCoordinate: RoutingCoordinate

    /// Creates a traffic segment snapshot.
    public init(
        id: UUID = UUID(),
        startArcLengthMeters: Double,
        endArcLengthMeters: Double,
        congestionLevel: TrafficCongestionLevel,
        currentSpeedKmh: Double,
        freeFlowSpeedKmh: Double,
        sampleCoordinate: RoutingCoordinate
    ) {
        self.id = id
        self.startArcLengthMeters = startArcLengthMeters
        self.endArcLengthMeters = endArcLengthMeters
        self.congestionLevel = congestionLevel
        self.currentSpeedKmh = currentSpeedKmh
        self.freeFlowSpeedKmh = freeFlowSpeedKmh
        self.sampleCoordinate = sampleCoordinate
    }
}
