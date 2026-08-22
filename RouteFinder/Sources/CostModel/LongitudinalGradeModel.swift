import Contracts
import Foundation

/// Inputs for grade-aware longitudinal speed integration.
public struct LongitudinalGradeInput: Sendable {
    /// Road grade in percent; positive uphill, negative downhill.
    public let gradePercent: Double
    /// Current longitudinal speed in meters per second.
    public let currentSpeedMps: Double
    /// Target cruise speed from legal, curve, cruise, and signal limits (no downhill penalty).
    public let targetSpeedMps: Double
    /// Vehicle mass in kilograms.
    public let vehicleMassKg: Double
    /// When true, passenger-car grade rules apply.
    public let isPassengerCar: Bool
    /// Base maximum acceleration in m/s².
    public let baseAccelMps2: Double
    /// Base maximum service braking deceleration in m/s².
    public let baseDecelMps2: Double
    /// Uphill load multiplier (≥ 1); affects HGV acceleration cap only.
    public let uphillLoadMultiplier: Double
    /// Active brake fade risk from thermal modeling.
    public let brakeFadeRisk: BrakeFadeRisk?
    /// Vehicle weight in tonnes for environmental grade caps.
    public let weightTonnes: Double?
    /// Engine-power-limited acceleration cap in m/s².
    public let engineAccelCapMps2: Double

    /// Creates longitudinal grade integration inputs.
    public init(
        gradePercent: Double,
        currentSpeedMps: Double,
        targetSpeedMps: Double,
        vehicleMassKg: Double,
        isPassengerCar: Bool,
        baseAccelMps2: Double,
        baseDecelMps2: Double,
        uphillLoadMultiplier: Double,
        brakeFadeRisk: BrakeFadeRisk?,
        weightTonnes: Double?,
        engineAccelCapMps2: Double
    ) {
        self.gradePercent = gradePercent
        self.currentSpeedMps = currentSpeedMps
        self.targetSpeedMps = targetSpeedMps
        self.vehicleMassKg = vehicleMassKg
        self.isPassengerCar = isPassengerCar
        self.baseAccelMps2 = baseAccelMps2
        self.baseDecelMps2 = baseDecelMps2
        self.uphillLoadMultiplier = uphillLoadMultiplier
        self.brakeFadeRisk = brakeFadeRisk
        self.weightTonnes = weightTonnes
        self.engineAccelCapMps2 = engineAccelCapMps2
    }
}

/// Result of a single longitudinal grade integration step.
public struct LongitudinalGradeOutput: Sendable {
    /// Signed net longitudinal acceleration applied this step.
    public let netAccelerationMps2: Double
    /// Effective acceleration cap after grade and load.
    public let effectiveAccelCapMps2: Double
    /// Effective service braking deceleration after grade and fade.
    public let effectiveDecelCapMps2: Double

    /// Creates a longitudinal grade output snapshot.
    public init(
        netAccelerationMps2: Double,
        effectiveAccelCapMps2: Double,
        effectiveDecelCapMps2: Double
    ) {
        self.netAccelerationMps2 = netAccelerationMps2
        self.effectiveAccelCapMps2 = effectiveAccelCapMps2
        self.effectiveDecelCapMps2 = effectiveDecelCapMps2
    }
}

/// Unified grade-aware longitudinal kinematics for route simulation.
public enum LongitudinalGradeModel: Sendable {
    /// Standard gravity in m/s².
    public static let gravityMps2 = RouteDynamicsPhysics.gravityMps2
    /// Passive downhill coasting scale applied to gravitational assist.
    public static let coastingFactor = 0.85
    private static let speedEpsilonMps = 0.05

    /// Converts grade percent to grade angle in radians.
    public static func gradeAngleRadians(fromPercent gradePercent: Double) -> Double {
        atan(gradePercent / 100.0)
    }

    /// Gravitational longitudinal assist: positive downhill, negative uphill.
    public static func gravityAssistMps2(gradePercent: Double) -> Double {
        let theta = gradeAngleRadians(fromPercent: gradePercent)
        return -gravityMps2 * sin(theta)
    }

    /// Effective acceleration cap including grade and uphill load.
    public static func effectiveAccelCapMps2(
        baseAccelMps2: Double,
        gradePercent: Double,
        uphillLoadMultiplier: Double,
        weightTonnes: Double?
    ) -> Double {
        let gradeLimited = TopographicalGradientEngine.effectiveMaxAccelerationMps2(
            maxAccelerationMps2: baseAccelMps2,
            gradePercent: gradePercent
        )
        let environmental = EnvironmentalPhysics.effectiveMaxAccel(
            base: baseAccelMps2,
            gradePercent: gradePercent,
            weightTonnes: weightTonnes
        )
        let loadDivisor = max(uphillLoadMultiplier, 1.0)
        return min(environmental, gradeLimited / loadDivisor)
    }

    /// Effective service braking deceleration including grade, mass, and brake fade.
    public static func effectiveDecelCapMps2(
        baseDecelMps2: Double,
        gradePercent: Double,
        weightTonnes: Double?,
        brakeFadeRisk: BrakeFadeRisk?
    ) -> Double {
        var decel = EnvironmentalPhysics.effectiveMaxDecel(
            base: baseDecelMps2,
            gradePercent: gradePercent,
            weightTonnes: weightTonnes
        )
        if let brakeFadeRisk {
            switch brakeFadeRisk {
            case .elevated:
                decel *= 0.75
            case .critical:
                decel *= 0.5
            }
        }
        return max(0.1, decel)
    }

    /// Integrates longitudinal speed for one simulation step.
    public static func integrate(
        input: LongitudinalGradeInput,
        deltaTime: Double,
        requiredDecelerationMps2: Double = 0
    ) -> (newSpeedMps: Double, output: LongitudinalGradeOutput) {
        guard deltaTime > 0 else {
            return (
                input.currentSpeedMps,
                LongitudinalGradeOutput(
                    netAccelerationMps2: 0,
                    effectiveAccelCapMps2: 0,
                    effectiveDecelCapMps2: 0
                )
            )
        }

        let assist = gravityAssistMps2(gradePercent: input.gradePercent)
        let environmentalAccelCap = effectiveAccelCapMps2(
            baseAccelMps2: input.baseAccelMps2,
            gradePercent: input.gradePercent,
            uphillLoadMultiplier: input.uphillLoadMultiplier,
            weightTonnes: input.weightTonnes
        )
        let accelCap = min(
            input.engineAccelCapMps2,
            environmentalAccelCap
        )
        var decelCap = effectiveDecelCapMps2(
            baseDecelMps2: input.baseDecelMps2,
            gradePercent: input.gradePercent,
            weightTonnes: input.weightTonnes,
            brakeFadeRisk: input.brakeFadeRisk
        )
        if requiredDecelerationMps2 > 0 {
            decelCap = min(decelCap, requiredDecelerationMps2)
        }

        let vTarget = input.targetSpeedMps
        var speed = input.currentSpeedMps
        var netAcceleration = 0.0
        let isDownhill = input.gradePercent < 0
        let isUphill = input.gradePercent > 0

        if isDownhill {
            if speed < vTarget - speedEpsilonMps {
                let gravityAccel = assist
                if input.isPassengerCar {
                    netAcceleration = gravityAccel
                    speed = min(vTarget, speed + gravityAccel * deltaTime)
                } else {
                    let netAccel = min(gravityAccel, accelCap)
                    netAcceleration = netAccel
                    speed = min(vTarget, speed + netAccel * deltaTime)
                }
            } else if speed > vTarget + speedEpsilonMps {
                if assist >= decelCap {
                    netAcceleration = 0
                    speed = max(vTarget, speed - decelCap * deltaTime * 0.5)
                    speed = min(speed, vTarget + speedEpsilonMps)
                } else {
                    let netDecel = max(0.1, decelCap - assist)
                    netAcceleration = -netDecel
                    speed = max(vTarget, speed - netDecel * deltaTime)
                }
            } else {
                netAcceleration = 0
                speed = min(vTarget, max(speed, vTarget - speedEpsilonMps))
            }
        } else if isUphill {
            let gravityRetardation = abs(assist)
            let engineForceCap = input.engineAccelCapMps2 + gravityRetardation
            let uphillAccel = min(accelCap, engineForceCap - gravityRetardation)
            netAcceleration = max(uphillAccel, -gravityRetardation)
            speed += netAcceleration * deltaTime
            if !input.isPassengerCar,
               input.gradePercent > EnvironmentalPhysics.steepUphillGradePercent {
                let baselineCreepSpeedMps = 6.0
                let crawlFloor = min(baselineCreepSpeedMps, vTarget)
                if speed < crawlFloor {
                    speed = crawlFloor
                    netAcceleration = 0
                }
            }
            speed = min(vTarget, max(0, speed))
        } else if speed < vTarget - speedEpsilonMps {
            netAcceleration = accelCap
            speed = min(vTarget, speed + accelCap * deltaTime)
        } else if speed > vTarget + speedEpsilonMps {
            let netDecel = max(0.05, decelCap)
            netAcceleration = -netDecel
            speed = max(vTarget, speed - netDecel * deltaTime)
        }

        speed = max(0, speed)

        return (
            speed,
            LongitudinalGradeOutput(
                netAccelerationMps2: netAcceleration,
                effectiveAccelCapMps2: accelCap,
                effectiveDecelCapMps2: decelCap
            )
        )
    }
}
