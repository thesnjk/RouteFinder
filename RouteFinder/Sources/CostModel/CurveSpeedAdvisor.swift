import Contracts
import Foundation

/// Heuristic advisor for safe cornering speed based on vehicle weight and turn angle.
public enum CurveSpeedAdvisor {
    /// Returns a recommended speed in km/h for a turn, or nil when no advisory applies.
    public static func recommendedSpeedKmh(
        turnAngleDegrees: Double,
        vehicleWeightTonnes: Double?,
        edgeSpeedKmh: Double
    ) -> Double? {
        guard turnAngleDegrees >= 15 else { return nil }

        let weight = vehicleWeightTonnes ?? 7.5
        let sharpness = min(abs(turnAngleDegrees) / 90.0, 1.0)
        let weightFactor = min(weight / 40.0, 1.5)
        let reduction = 0.15 + sharpness * 0.35 * weightFactor
        let cap = edgeSpeedKmh > 0 ? edgeSpeedKmh : CostConstants.defaultSpeedKmh
        let advised = cap * (1.0 - reduction)
        return max(20, min(advised, cap))
    }

    /// Maximum safe cornering speed from lateral acceleration: `v = sqrt(a_lateral × g × R)`.
    public static func maxCurveSpeedMps(radiusMeters: Double, lateralG: Double) -> Double {
        guard radiusMeters.isFinite else { return .infinity }
        guard radiusMeters > 1 else { return 0 }
        let clampedG = max(0.05, lateralG)
        return sqrt(clampedG * RouteDynamicsPhysics.gravityMps2 * radiusMeters)
    }

    /// Minimum upcoming curve speed over a lookahead window (tightest bend wins).
    public static func maxUpcomingCurveSpeedMps(
        cumulativeLengths: [Double],
        coordinates: [Coordinate],
        arcLength: Double,
        lookaheadM: Double,
        lateralG: Double,
        friction: Double = RouteDynamicsPhysics.defaultDryFrictionCoefficient,
        currentSpeedMps: Double = 0,
        minimumTurnRadiusMeters: Double? = nil
    ) -> Double {
        guard coordinates.count >= 3, cumulativeLengths.count == coordinates.count else {
            return .infinity
        }

        let effectiveLateralG = EnvironmentalPhysics.effectiveLateralG(
            baseLateralG: lateralG,
            friction: friction
        )
        let endArc = arcLength + max(lookaheadM, 0)
        var minSpeed = Double.infinity

        for index in 2..<coordinates.count {
            let vertexArc = cumulativeLengths[index - 1]
            if vertexArc < arcLength { continue }
            if vertexArc > endArc { break }

            let radius = RouteDynamicsPhysics.turningRadiusMeters(
                p0: coordinates[index - 2],
                p1: coordinates[index - 1],
                p2: coordinates[index]
            )
            let effectiveRadius: Double
            if let minimumTurnRadiusMeters, minimumTurnRadiusMeters > 0, radius.isFinite {
                effectiveRadius = max(radius, minimumTurnRadiusMeters)
            } else {
                effectiveRadius = radius
            }
            let speed = maxCurveSpeedMps(radiusMeters: effectiveRadius, lateralG: effectiveLateralG)
            minSpeed = min(minSpeed, speed)
        }

        if minSpeed.isInfinite {
            return .infinity
        }

        if currentSpeedMps < 1.0 {
            return max(minSpeed, RouteDynamicsPhysics.launchCrawlSpeedMps)
        }
        return minSpeed
    }
}
