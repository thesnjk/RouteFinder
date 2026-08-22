import Contracts
import Foundation

/// Environmental friction and grade-aware longitudinal kinematic limits.
public enum EnvironmentalPhysics {
    /// Steep uphill grade threshold (percent) for HGV torque limiting.
    public static let steepUphillGradePercent = 6.0
    /// Steep downhill grade threshold (percent) for brake fade limiting.
    public static let steepDownhillGradePercent = -6.0
    /// HGV weight threshold (tonnes) for grade-based limiting.
    public static let heavyVehicleWeightTonnes = 20.0

    /// Scales lateral G from a base value using the active friction coefficient.
    public static func effectiveLateralG(baseLateralG: Double, friction: Double) -> Double {
        let baseline = RouteDynamicsPhysics.defaultDryFrictionCoefficient
        let scale = friction / baseline
        return max(0.05, baseLateralG * scale)
    }

    /// Caps maximum acceleration based on road grade and vehicle mass.
    public static func effectiveMaxAccel(
        base: Double,
        gradePercent: Double,
        weightTonnes: Double?
    ) -> Double {
        let weight = weightTonnes ?? 7.5
        guard weight >= heavyVehicleWeightTonnes, gradePercent > steepUphillGradePercent else {
            return base
        }
        let excess = min((gradePercent - steepUphillGradePercent) / 10.0, 1.0)
        let penalty = 0.45 + (1.0 - excess) * 0.35
        return base * penalty
    }

    /// Caps maximum service braking deceleration based on downhill grade and vehicle mass.
    public static func effectiveMaxDecel(
        base: Double,
        gradePercent: Double,
        weightTonnes: Double?
    ) -> Double {
        let weight = weightTonnes ?? 7.5
        guard weight >= heavyVehicleWeightTonnes, gradePercent < steepDownhillGradePercent else {
            return base
        }
        let magnitude = abs(gradePercent - steepDownhillGradePercent)
        let excess = min(magnitude / 10.0, 1.0)
        let penalty = 0.65 + (1.0 - excess) * 0.25
        return base * penalty
    }
}
