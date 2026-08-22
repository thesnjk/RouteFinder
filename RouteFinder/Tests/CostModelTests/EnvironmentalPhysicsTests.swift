import Contracts
import CostModel
import Foundation
import Testing

struct EnvironmentalPhysicsTests {
    @Test func rainReducesEffectiveLateralG() {
        let dry = EnvironmentalPhysics.effectiveLateralG(
            baseLateralG: 0.16,
            friction: EnvironmentalContext.dry.frictionCoefficient
        )
        let rain = EnvironmentalPhysics.effectiveLateralG(
            baseLateralG: 0.16,
            friction: EnvironmentalContext.rain.frictionCoefficient
        )

        #expect(rain < dry)
    }

    @Test func steepUphillLimitsHGVAcceleration() {
        let flat = EnvironmentalPhysics.effectiveMaxAccel(
            base: 1.2,
            gradePercent: 2,
            weightTonnes: 44
        )
        let uphill = EnvironmentalPhysics.effectiveMaxAccel(
            base: 1.2,
            gradePercent: 10,
            weightTonnes: 44
        )

        #expect(uphill < flat)
    }

    @Test func steepDownhillLimitsHGVDeceleration() {
        let flat = EnvironmentalPhysics.effectiveMaxDecel(
            base: 2.0,
            gradePercent: -1,
            weightTonnes: 44
        )
        let downhill = EnvironmentalPhysics.effectiveMaxDecel(
            base: 2.0,
            gradePercent: -10,
            weightTonnes: 44
        )

        #expect(downhill < flat)
    }

    @Test func iceFrictionLowestAmongContexts() {
        #expect(EnvironmentalContext.ice.frictionCoefficient < EnvironmentalContext.rain.frictionCoefficient)
        #expect(EnvironmentalContext.rain.frictionCoefficient < EnvironmentalContext.dry.frictionCoefficient)
    }
}
