import Contracts
import Foundation

/// Topographical gradient modeling with uphill throttle limiting and downhill thermal brake fade.
public struct TopographicalGradientEngine: Sendable {
    /// Standard gravity in m/s².
    public static let gravityMps2 = RouteDynamicsPhysics.gravityMps2

    /// Sustained negative gradient threshold (degrees) for thermal brake fade tracking.
    public static let sustainedDownhillThresholdDegrees = -3.0

    /// Critical thermal load threshold in joules before brake fade risk is flagged.
    public static let criticalThermalLoadJoules = BrakeThermalThresholds.criticalLoadJoules

    /// Elevated thermal load threshold in joules.
    public static let elevatedThermalLoadJoules = BrakeThermalThresholds.elevatedLoadJoules

    /// Thermal dissipation rate per second when not on sustained downhill.
    public static let thermalDissipationRatePerSecond = 120_000.0

    private var thermalLoadAccumulatorJoules: Double = 0

    /// Creates a topographical gradient engine with zero initial thermal load.
    public init() {}

    /// Converts grade percent to grade angle in radians.
    public static func gradeAngleRadians(fromGradePercent gradePercent: Double) -> Double {
        atan(gradePercent / 100.0)
    }

    /// Converts grade percent to grade angle in degrees.
    public static func gradeAngleDegrees(fromGradePercent gradePercent: Double) -> Double {
        gradeAngleRadians(fromGradePercent: gradePercent) * 180.0 / .pi
    }

    /// Computes effective maximum acceleration: `a_effective = a_max - (g * sin(theta))`.
    public static func effectiveMaxAccelerationMps2(
        maxAccelerationMps2: Double,
        gradePercent: Double
    ) -> Double {
        let theta = gradeAngleRadians(fromGradePercent: gradePercent)
        let gradePenalty = gravityMps2 * sin(theta)
        return max(0.05, maxAccelerationMps2 - gradePenalty)
    }

    /// Advances thermal brake fade accumulator for sustained negative gradients.
    ///
    /// `ThermalLoad += mass * g * sin(abs(theta)) * velocity * dt`
    public mutating func advanceThermalLoad(
        gradePercent: Double,
        velocityMps: Double,
        massKg: Double,
        deltaTime: Double
    ) -> TopographyGradientState {
        let gradeDegrees = Self.gradeAngleDegrees(fromGradePercent: gradePercent)

        if gradeDegrees < Self.sustainedDownhillThresholdDegrees, velocityMps > 0.5 {
            let theta = Self.gradeAngleRadians(fromGradePercent: gradePercent)
            let dissipation = massKg * Self.gravityMps2 * sin(abs(theta)) * velocityMps * deltaTime
            thermalLoadAccumulatorJoules += dissipation
        } else if deltaTime > 0 {
            thermalLoadAccumulatorJoules = max(
                0,
                thermalLoadAccumulatorJoules - Self.thermalDissipationRatePerSecond * deltaTime
            )
        }

        let brakeFadeRisk: BrakeFadeRisk?
        if thermalLoadAccumulatorJoules >= Self.criticalThermalLoadJoules {
            brakeFadeRisk = .critical
        } else if thermalLoadAccumulatorJoules >= Self.elevatedThermalLoadJoules {
            brakeFadeRisk = .elevated
        } else {
            brakeFadeRisk = nil
        }

        return TopographyGradientState(
            gradeAngleDegrees: gradeDegrees,
            effectiveMaxAccelerationMps2: 0,
            thermalLoadJoules: thermalLoadAccumulatorJoules,
            brakeFadeRisk: brakeFadeRisk
        )
    }

    /// Current thermal load in joules.
    public var currentThermalLoadJoules: Double {
        thermalLoadAccumulatorJoules
    }

    /// Resets thermal accumulator to zero.
    public mutating func resetThermalLoad() {
        thermalLoadAccumulatorJoules = 0
    }
}
