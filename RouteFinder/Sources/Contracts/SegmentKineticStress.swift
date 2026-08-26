import Foundation

/// Pre-computed kinetic stress for a single route segment derived from 3D topology.
public struct SegmentKineticStress: Codable, Sendable, Equatable, Hashable {
    /// Road grade as a percentage (rise over run × 100).
    public let gradePercentage: Double
    /// Normalized brake thermal stress from 0.0 to 1.0 on descending grades.
    public let thermalStressScore: Double
    /// Uphill load multiplier (≥ 1) applied to HGV acceleration caps; always 1 on flat/downhill.
    public let loadMultiplier: Double

    /// Uphill-only load multiplier for acceleration limiting.
    public var uphillLoadMultiplier: Double {
        max(loadMultiplier, 1.0)
    }

    /// Creates a segment kinetic stress sample.
    public init(
        gradePercentage: Double,
        thermalStressScore: Double,
        loadMultiplier: Double
    ) {
        self.gradePercentage = gradePercentage
        self.thermalStressScore = thermalStressScore
        self.loadMultiplier = loadMultiplier
    }

    /// Neutral stress with no grade influence.
    public static let neutral = SegmentKineticStress(
        gradePercentage: 0,
        thermalStressScore: 0,
        loadMultiplier: 1
    )
}
