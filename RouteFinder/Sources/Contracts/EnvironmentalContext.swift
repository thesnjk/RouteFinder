/// Road surface and weather conditions affecting vehicle friction and braking.
public enum EnvironmentalContext: String, Codable, Sendable, Hashable, CaseIterable {
    /// Dry asphalt with nominal grip.
    case dry
    /// Wet road surface with reduced friction.
    case rain
    /// Icy or snow-covered surface with minimal grip.
    case ice

    /// Display label for UI pickers.
    public var displayName: String {
        switch self {
        case .dry: return "Dry"
        case .rain: return "Rain"
        case .ice: return "Ice"
        }
    }

    /// Road surface friction coefficient (µ) on dry asphalt baseline 0.8.
    public var frictionCoefficient: Double {
        switch self {
        case .dry: return 0.80
        case .rain: return 0.40
        case .ice: return 0.15
        }
    }

    /// Multiplier applied to curve/braking lookahead distance.
    public var curveLookaheadMultiplier: Double {
        switch self {
        case .dry: return 1.0
        case .rain: return 1.4
        case .ice: return 2.0
        }
    }
}
