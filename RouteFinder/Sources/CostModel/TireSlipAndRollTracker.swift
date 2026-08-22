import Contracts
import Foundation

/// Tracks tire slip angle and body roll proxy during route simulation.
public struct TireSlipAndRollTracker: Sendable {
    /// Maximum slip angle before event emission (degrees).
    public static let slipAngleThresholdDegrees = 4.0

    /// Maximum slip angle cap (degrees).
    public static let maxSlipAngleDegrees = 8.0

    /// Lateral G fraction of limit before violation event (0–1).
    public static let lateralGViolationFraction = 0.85

    /// HGV track width in meters.
    public static let hgvTrackWidthMeters = 2.0

    /// Passenger car track width in meters.
    public static let passengerTrackWidthMeters = 1.55

    /// HGV roll stiffness proxy (N·m/rad scale factor).
    public static let hgvRollStiffness = 180_000.0

    /// Passenger car roll stiffness proxy.
    public static let passengerRollStiffness = 45_000.0

    private let isPassengerCar: Bool
    private let maxLateralG: Double
    private let frictionCoefficient: Double

    /// Creates a tire slip and body roll tracker for the given vehicle class.
    public init(
        isPassengerCar: Bool,
        maxLateralG: Double,
        frictionCoefficient: Double = RouteDynamicsPhysics.defaultDryFrictionCoefficient
    ) {
        self.isPassengerCar = isPassengerCar
        self.maxLateralG = maxLateralG
        self.frictionCoefficient = frictionCoefficient
    }

    /// Slip angle estimate: `alpha = atan(lateralAccel / (g * mu))` capped at 8°.
    public func slipAngleDegrees(lateralAccelerationMps2: Double) -> Double {
        let denominator = RouteDynamicsPhysics.gravityMps2 * max(0.05, frictionCoefficient)
        let radians = atan(lateralAccelerationMps2 / denominator)
        let degrees = radians * 180.0 / .pi
        return min(max(0, degrees), Self.maxSlipAngleDegrees)
    }

    /// Body roll proxy: `phi = lateralG * trackWidth / (2 * rollStiffness)`.
    public func bodyRollDegrees(lateralG: Double) -> Double {
        let trackWidth = isPassengerCar ? Self.passengerTrackWidthMeters : Self.hgvTrackWidthMeters
        let stiffness = isPassengerCar ? Self.passengerRollStiffness : Self.hgvRollStiffness
        let rollRadians = lateralG * trackWidth / (2.0 * stiffness)
        return rollRadians * 180.0 / .pi
    }

    /// Evaluates lateral dynamics and returns events if thresholds are exceeded.
    public func evaluate(
        speedMps: Double,
        turningRadiusMeters: Double,
        arcLengthMeters: Double,
        elapsedSeconds: TimeInterval
    ) -> [SimulationEvent] {
        guard speedMps > 0.5, turningRadiusMeters.isFinite, turningRadiusMeters > 1 else {
            return []
        }

        var events: [SimulationEvent] = []
        let lateralAcceleration = (speedMps * speedMps) / turningRadiusMeters
        let lateralG = lateralAcceleration / RouteDynamicsPhysics.gravityMps2
        let slipAngle = slipAngleDegrees(lateralAccelerationMps2: lateralAcceleration)

        if lateralG > maxLateralG * Self.lateralGViolationFraction {
            events.append(SimulationEvent(
                kind: .lateralGViolation,
                arcLengthMeters: arcLengthMeters,
                elapsedSeconds: elapsedSeconds,
                magnitude: lateralG
            ))
        }

        if slipAngle > Self.slipAngleThresholdDegrees {
            events.append(SimulationEvent(
                kind: .tireSlip,
                arcLengthMeters: arcLengthMeters,
                elapsedSeconds: elapsedSeconds,
                magnitude: slipAngle
            ))
        }

        return events
    }
}
