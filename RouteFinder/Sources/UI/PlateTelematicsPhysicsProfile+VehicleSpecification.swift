import Contracts
import CostModel
import RouteController

extension PlateTelematicsPhysicsProfile {
    /// Builds a telematics profile from a registry specification and routing mode.
    public static func from(
        profile: VehicleSpecificationProfile?,
        isPassengerCar: Bool,
        fallbackHP: Double,
        fallbackMassKg: Double? = nil
    ) -> PlateTelematicsPhysicsProfile {
        let massKg: Double
        if let profile, profile.grossWeightKilograms > 0 {
            massKg = profile.grossWeightKilograms
        } else if let fallbackMassKg, fallbackMassKg > 0 {
            massKg = fallbackMassKg
        } else {
            massKg = isPassengerCar ? 1500 : 44_000
        }

        let resolvedHP: Double
        if let profileHP = profile?.enginePowerHorsepower, profileHP > 0 {
            resolvedHP = Double(profileHP)
        } else {
            resolvedHP = fallbackHP
        }

        let wheelbase = profile?.wheelbaseMeters ?? (isPassengerCar ? 2.7 : 6.5)
        return from(
            massKg: massKg,
            powerHP: resolvedHP,
            wheelbaseMeters: wheelbase,
            isPassengerCar: isPassengerCar
        )
    }
}
