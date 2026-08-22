import Foundation

/// Telematics-derived physics parameters from a resolved vehicle specification profile.
public struct PlateTelematicsPhysicsProfile: Sendable, Equatable {
    /// Vehicle mass in kilograms.
    public let massKg: Double
    /// Engine power in watts.
    public let powerWatts: Double
    /// Engine power in horsepower.
    public let powerHP: Double
    /// Power-to-weight ratio in watts per kilogram.
    public let powerToWeightWPerKg: Double
    /// Wheelbase in meters for Ackermann steering.
    public let wheelbaseMeters: Double
    /// When true, passenger-car friction and lateral limits apply.
    public let isPassengerCar: Bool

    /// Creates a telematics physics profile.
    public init(
        massKg: Double,
        powerWatts: Double,
        powerHP: Double,
        powerToWeightWPerKg: Double,
        wheelbaseMeters: Double,
        isPassengerCar: Bool
    ) {
        self.massKg = massKg
        self.powerWatts = powerWatts
        self.powerHP = powerHP
        self.powerToWeightWPerKg = powerToWeightWPerKg
        self.wheelbaseMeters = wheelbaseMeters
        self.isPassengerCar = isPassengerCar
    }

    /// Builds a telematics profile from resolved plate parameters.
    public static func from(
        massKg: Double,
        powerHP: Double,
        wheelbaseMeters: Double,
        isPassengerCar: Bool
    ) -> PlateTelematicsPhysicsProfile {
        let resolvedMass = isPassengerCar ? max(massKg, 1200) : max(massKg, 3500)
        let resolvedHP = max(powerHP, 50)
        let powerWatts = resolvedHP * 745.7
        let powerToWeight = powerWatts / resolvedMass

        return PlateTelematicsPhysicsProfile(
            massKg: resolvedMass,
            powerWatts: powerWatts,
            powerHP: resolvedHP,
            powerToWeightWPerKg: powerToWeight,
            wheelbaseMeters: wheelbaseMeters,
            isPassengerCar: isPassengerCar
        )
    }

    /// Vehicle weight in tonnes.
    public var weightTonnes: Double {
        massKg / 1000.0
    }
}
