import Contracts
import Foundation

/// Ackermann- and geometry-aware curve speed governor with polyline noise filtering.
public enum CentripetalSpeedGovernor: Sendable {
    /// Minimum bearing change between segments to treat as a meaningful curve (degrees).
    /// Raised above densify noise on 5 m simulation spines.
    public static let minimumSignificantBearingDeltaDeg = 6.0
    /// Radius above which the corridor is treated as straight (meters).
    public static let straightCorridorRadiusMeters = 250.0
    /// Radius below which full lateral-G cap applies (meters).
    public static let tightCurveRadiusMeters = 50.0

    /// Steering kinematics snapshot used for Ackermann-derived turn radius.
    public struct SteeringSnapshot: Sendable, Equatable {
        /// Ackermann steering angle in radians.
        public let steerAngleRadians: Double
        /// Vehicle wheelbase in meters.
        public let wheelbaseMeters: Double

        /// Creates a steering snapshot.
        public init(steerAngleRadians: Double, wheelbaseMeters: Double) {
            self.steerAngleRadians = steerAngleRadians
            self.wheelbaseMeters = wheelbaseMeters
        }

        /// Instantaneous turn radius from bicycle model: R = wheelbase / tan(δ).
        public var ackermannTurnRadiusMeters: Double {
            let safeWheelbase = max(wheelbaseMeters, 0.1)
            let steer = abs(steerAngleRadians)
            guard steer > 0.01 else { return .infinity }
            return safeWheelbase / tan(min(steer, 0.6))
        }
    }

    /// Maximum safe speed for upcoming curves with noise filtering and Ackermann radius blending.
    public static func maxUpcomingCurveSpeedMps(
        cumulativeLengths: [Double],
        coordinates: [Coordinate],
        arcLength: Double,
        lookaheadM: Double,
        lateralG: Double,
        friction: Double = RouteDynamicsPhysics.defaultDryFrictionCoefficient,
        currentSpeedMps: Double = 0,
        minimumTurnRadiusMeters: Double? = nil,
        steeringSnapshot: SteeringSnapshot? = nil
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

            let bearingDelta = abs(bearingDeltaDegrees(
                from: coordinates[index - 2],
                via: coordinates[index - 1],
                to: coordinates[index]
            ))
            if bearingDelta < minimumSignificantBearingDeltaDeg {
                continue
            }

            let geometricRadius = RouteDynamicsPhysics.turningRadiusMeters(
                p0: coordinates[index - 2],
                p1: coordinates[index - 1],
                p2: coordinates[index]
            )

            if geometricRadius.isFinite, geometricRadius > straightCorridorRadiusMeters {
                continue
            }

            var effectiveRadius = geometricRadius
            if let minimumTurnRadiusMeters, minimumTurnRadiusMeters > 0, effectiveRadius.isFinite {
                effectiveRadius = max(effectiveRadius, minimumTurnRadiusMeters)
            }
            if let steeringSnapshot {
                let ackermannRadius = steeringSnapshot.ackermannTurnRadiusMeters
                if ackermannRadius.isFinite {
                    effectiveRadius = max(effectiveRadius, ackermannRadius)
                }
            }

            if effectiveRadius.isFinite, effectiveRadius > straightCorridorRadiusMeters {
                continue
            }

            let speed = CurveSpeedAdvisor.maxCurveSpeedMps(
                radiusMeters: effectiveRadius,
                lateralG: effectiveLateralG
            )
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

    private static func bearingDeltaDegrees(from: Coordinate, via: Coordinate, to: Coordinate) -> Double {
        let bearingIn = segmentBearing(from: from, to: via)
        let bearingOut = segmentBearing(from: via, to: to)
        var delta = bearingOut - bearingIn
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    private static func segmentBearing(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * Double.pi / 180
        let lat2 = to.latitude * Double.pi / 180
        let deltaLon = (to.longitude - from.longitude) * Double.pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        var degrees = atan2(y, x) * 180 / Double.pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }
}
