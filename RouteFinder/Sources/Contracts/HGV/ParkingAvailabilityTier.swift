import Foundation

/// Driver-facing parking / layby availability band (CoPilot-style color tiers).
public enum ParkingAvailabilityTier: String, Sendable, Hashable, Codable, CaseIterable {
    /// Spaces likely available.
    case ample
    /// Mixed / uncertain availability.
    case limited
    /// Likely full or evening peak pressure.
    case full

    /// Confidence at or above this maps to ``ample``.
    public static let ampleConfidenceFloor: Double = 0.70
    /// Confidence at or above this (and below ample) maps to ``limited``.
    public static let limitedConfidenceFloor: Double = 0.45

    /// Inverts occupancy prior (low occupancy → ample spaces).
    public init(occupancyPrior: LaybyOccupancyPrior) {
        switch occupancyPrior {
        case .low: self = .ample
        case .moderate: self = .limited
        case .high: self = .full
        }
    }

    /// Maps post-adjust POI confidence into availability bands.
    public init(confidence: Double) {
        let clamped = min(1, max(0, confidence))
        if clamped >= Self.ampleConfidenceFloor {
            self = .ample
        } else if clamped >= Self.limitedConfidenceFloor {
            self = .limited
        } else {
            self = .full
        }
    }

    /// Short chip label.
    public var displayLabel: String {
        switch self {
        case .ample: return "Spaces"
        case .limited: return "Limited"
        case .full: return "Full"
        }
    }

    /// SF Symbol for badges and banner leading icons.
    public var systemImageName: String {
        switch self {
        case .ample: return "parkingsign.circle.fill"
        case .limited: return "exclamationmark.triangle.fill"
        case .full: return "xmark.circle.fill"
        }
    }

    /// VoiceOver / accessibility label.
    public var accessibilityLabel: String {
        switch self {
        case .ample: return "Parking availability: spaces likely"
        case .limited: return "Parking availability: limited"
        case .full: return "Parking availability: likely full"
        }
    }
}
