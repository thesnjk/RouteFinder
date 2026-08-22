import Foundation

/// Fixed longitudinal rates for smooth transitions between posted speed zones.
public struct LongitudinalTransitionProfile: Sendable, Equatable {
    /// Maximum acceleration when approaching a higher speed limit (m/s²).
    public let accelerationMps2: Double
    /// Maximum service braking when approaching a lower speed limit (m/s²).
    public let decelerationMps2: Double
    /// Deadband around target speed to avoid limit-boundary oscillation (m/s).
    public let limitChangeHysteresisMps: Double

    /// Creates a longitudinal transition profile.
    public init(
        accelerationMps2: Double = 1.5,
        decelerationMps2: Double = 2.5,
        limitChangeHysteresisMps: Double = 0.5
    ) {
        self.accelerationMps2 = accelerationMps2
        self.decelerationMps2 = decelerationMps2
        self.limitChangeHysteresisMps = limitChangeHysteresisMps
    }

    /// Default zone-transition profile for passenger cars and HGVs.
    public static let standard = LongitudinalTransitionProfile()
}
