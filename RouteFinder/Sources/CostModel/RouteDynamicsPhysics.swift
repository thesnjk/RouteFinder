import Contracts
import Foundation

/// Physics helpers for route simulation: curvature limits and weight-scaled kinematics.
public enum RouteDynamicsPhysics {
    /// Default friction coefficient for laden HGV tyres on dry asphalt.
    public static let defaultFrictionCoefficient = 0.35

    /// Nominal dry-road friction coefficient used for environmental scaling.
    public static let defaultDryFrictionCoefficient = 0.80

    /// Standard gravity in m/s².
    public static let gravityMps2 = 9.81

    /// Computes the turning radius at the middle point of three coordinates in meters.
    ///
    /// Returns infinity when points are collinear or coincident.
    public static func turningRadiusMeters(p0: Coordinate, p1: Coordinate, p2: Coordinate) -> Double {
        let a = haversineMeters(p0, p1)
        let b = haversineMeters(p1, p2)
        let c = haversineMeters(p0, p2)

        guard a > 0.5, b > 0.5 else { return .infinity }

        let semiPerimeter = (a + b + c) / 2
        let areaSquared = semiPerimeter
            * (semiPerimeter - a)
            * (semiPerimeter - b)
            * (semiPerimeter - c)
        guard areaSquared > 1e-6 else { return .infinity }

        let area = sqrt(areaSquared)
        return (a * b * c) / (4 * area)
    }

    /// Maximum safe speed on a curve: `v_max = sqrt(μ * g * R)`.
    public static func maxCurveSpeedMps(
        radiusMeters: Double,
        friction: Double = defaultFrictionCoefficient
    ) -> Double {
        guard radiusMeters.isFinite, radiusMeters > 1 else { return 0 }
        let clampedFriction = max(0.05, friction)
        return sqrt(clampedFriction * gravityMps2 * radiusMeters)
    }

    /// Minimum curve speed floor used during launch from standstill.
    public static let launchCrawlSpeedMps = 2.0

    /// Applies a launch floor so zero-radius curves do not trap the vehicle at 0 m/s.
    public static func effectiveMaxCurveSpeedMps(
        radiusMeters: Double,
        currentSpeedMps: Double,
        friction: Double = defaultFrictionCoefficient
    ) -> Double {
        let raw = maxCurveSpeedMps(radiusMeters: radiusMeters, friction: friction)
        if currentSpeedMps < 1.0 {
            return max(raw, launchCrawlSpeedMps)
        }
        return raw
    }

    /// Default HGV engine power when profile input is missing.
    public static let defaultEnginePowerHP = 450.0

    /// Converts engine power to acceleration using `a = P / (m × v)` with a crawl-speed floor.
    public static func accelerationFromEnginePowerMps2(
        powerHP: Double = defaultEnginePowerHP,
        weightTonnes: Double?,
        currentSpeedMps: Double = 0
    ) -> Double {
        let massKg = max((weightTonnes ?? 7.5) * 1000, 3500)
        let watts = max(powerHP, 50) * 745.7
        let crawlSpeed = max(currentSpeedMps, 3.0)
        let engineDerived = watts / (massKg * crawlSpeed)
        let legacy = accelerationMps2(weightTonnes: weightTonnes)
        return max(legacy, engineDerived)
    }

    /// Weight-scaled acceleration for laden HGV (base 0.8 m/s² at ~7.5 t).
    public static func accelerationMps2(base: Double = 0.8, weightTonnes: Double?) -> Double {
        let weight = max(weightTonnes ?? 7.5, 3.5)
        let scale = min(weight / 44.0, 1.0)
        return base * (1.0 - scale * 0.55)
    }

    /// Weight-scaled deceleration (44 t laden → ~2.0 m/s² from base 3.5 m/s²).
    public static func decelerationMps2(base: Double = 3.5, weightTonnes: Double?) -> Double {
        let weight = max(weightTonnes ?? 7.5, 3.5)
        let scale = min(weight / 44.0, 1.0)
        return base * (1.0 - scale * 0.43)
    }

    /// Stopping distance from current speed and deceleration.
    public static func stoppingDistanceMeters(speedMps: Double, deceleration: Double) -> Double {
        guard speedMps > 0, deceleration > 0 else { return 0 }
        return (speedMps * speedMps) / (2 * deceleration)
    }

    /// Vehicle-class kinematic limits used by route simulation playback.
    public struct SimulationVehicleDynamics: Sendable, Hashable {
        /// Maximum lateral acceleration as a fraction of gravity (e.g. 0.16 g).
        public let lateralG: Double
        /// Maximum longitudinal acceleration in m/s².
        public let maxAccelMps2: Double
        /// Maximum service braking deceleration in m/s².
        public let maxDecelMps2: Double
        /// Maximum yaw rate for smoothed steering in degrees per second.
        public let maxYawRateDegPerSec: Double

        /// Creates simulation dynamics with explicit limits.
        public init(
            lateralG: Double,
            maxAccelMps2: Double,
            maxDecelMps2: Double,
            maxYawRateDegPerSec: Double
        ) {
            self.lateralG = lateralG
            self.maxAccelMps2 = maxAccelMps2
            self.maxDecelMps2 = maxDecelMps2
            self.maxYawRateDegPerSec = maxYawRateDegPerSec
        }

        /// Resolves HGV vs passenger-car limits from profile and routing mode.
        public static func forVehicle(weightTonnes: Double?, isPassengerCar: Bool) -> SimulationVehicleDynamics {
            if isPassengerCar {
                return SimulationVehicleDynamics(
                    lateralG: 0.32,
                    maxAccelMps2: 2.5,
                    maxDecelMps2: 4.5,
                    maxYawRateDegPerSec: 25
                )
            }

            let weight = weightTonnes ?? 44
            let lateralG = weight >= 20 ? 0.16 : 0.18
            return SimulationVehicleDynamics(
                lateralG: lateralG,
                maxAccelMps2: 1.2,
                maxDecelMps2: 2.0,
                maxYawRateDegPerSec: 8
            )
        }

        /// Resolves dynamics from plate telematics, scaling acceleration with power-to-weight.
        public static func from(telematics: PlateTelematicsPhysicsProfile) -> SimulationVehicleDynamics {
            if telematics.isPassengerCar {
                let plateAccel = plateDerivedAccelerationMps2(
                    powerToWeightWPerKg: telematics.powerToWeightWPerKg,
                    isPassengerCar: true
                )
                return SimulationVehicleDynamics(
                    lateralG: 0.32,
                    maxAccelMps2: min(plateAccel, 4.0),
                    maxDecelMps2: 4.5,
                    maxYawRateDegPerSec: 25
                )
            }

            let weight = telematics.weightTonnes
            let lateralG = weight >= 20 ? 0.16 : 0.18
            let plateAccel = plateDerivedAccelerationMps2(
                powerToWeightWPerKg: telematics.powerToWeightWPerKg,
                isPassengerCar: false
            )
            return SimulationVehicleDynamics(
                lateralG: lateralG,
                maxAccelMps2: min(plateAccel, 1.8),
                maxDecelMps2: 2.0,
                maxYawRateDegPerSec: 8
            )
        }

        private static func plateDerivedAccelerationMps2(
            powerToWeightWPerKg: Double,
            isPassengerCar: Bool
        ) -> Double {
            let crawlSpeedMps = 3.0
            let engineAccel = powerToWeightWPerKg / crawlSpeedMps
            if isPassengerCar {
                return max(1.2, min(engineAccel, 4.0))
            }
            return max(0.6, min(engineAccel, 1.8))
        }
    }

    private static func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180

        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
