import Contracts
import Foundation
import Testing
@testable import CostModel

struct LongitudinalGradeModelTests {
    @Test func downhillMaintainsTargetSpeedUnderBrakingPressure() {
        let input = LongitudinalGradeInput(
            gradePercent: -8,
            currentSpeedMps: 12.5,
            targetSpeedMps: 12.5,
            vehicleMassKg: 1500,
            isPassengerCar: true,
            baseAccelMps2: 2.5,
            baseDecelMps2: 3.5,
            uphillLoadMultiplier: 1,
            brakeFadeRisk: nil,
            weightTonnes: 1.5,
            engineAccelCapMps2: 2.0
        )

        let result = LongitudinalGradeModel.integrate(input: input, deltaTime: 0.1)

        #expect(result.newSpeedMps >= 12.0)
        #expect(result.output.netAccelerationMps2 >= 0)
    }

    @Test func uphillReducesAccelerationCap() {
        let uphillCap = LongitudinalGradeModel.effectiveAccelCapMps2(
            baseAccelMps2: 2.0,
            gradePercent: 10,
            uphillLoadMultiplier: 1,
            weightTonnes: 7.5
        )
        let flatCap = LongitudinalGradeModel.effectiveAccelCapMps2(
            baseAccelMps2: 2.0,
            gradePercent: 0,
            uphillLoadMultiplier: 1,
            weightTonnes: 7.5
        )

        #expect(uphillCap < flatCap)
    }

    @Test func brakeFadeReducesEffectiveDecel() {
        let faded = LongitudinalGradeModel.effectiveDecelCapMps2(
            baseDecelMps2: 3.5,
            gradePercent: -8,
            weightTonnes: 44,
            brakeFadeRisk: .critical
        )
        let normal = LongitudinalGradeModel.effectiveDecelCapMps2(
            baseDecelMps2: 3.5,
            gradePercent: -8,
            weightTonnes: 44,
            brakeFadeRisk: nil
        )

        #expect(faded < normal)
    }

    @Test func gravityAssistIsPositiveOnDownhill() {
        let assist = LongitudinalGradeModel.gravityAssistMps2(gradePercent: -10)
        #expect(assist > 0)
    }

    @Test func gravityAssistIsNegativeOnUphill() {
        let assist = LongitudinalGradeModel.gravityAssistMps2(gradePercent: 10)
        #expect(assist < 0)
    }

    @Test func passengerCarAcceleratesOnDownhillBelowTarget() {
        let input = LongitudinalGradeInput(
            gradePercent: -8,
            currentSpeedMps: 2.5,
            targetSpeedMps: 25.0 / 3.6,
            vehicleMassKg: 1850,
            isPassengerCar: true,
            baseAccelMps2: 2.5,
            baseDecelMps2: 3.5,
            uphillLoadMultiplier: 1,
            brakeFadeRisk: nil,
            weightTonnes: 1.85,
            engineAccelCapMps2: 2.0
        )

        var speed = input.currentSpeedMps
        for _ in 0..<120 {
            let step = LongitudinalGradeModel.integrate(
                input: LongitudinalGradeInput(
                    gradePercent: input.gradePercent,
                    currentSpeedMps: speed,
                    targetSpeedMps: input.targetSpeedMps,
                    vehicleMassKg: input.vehicleMassKg,
                    isPassengerCar: input.isPassengerCar,
                    baseAccelMps2: input.baseAccelMps2,
                    baseDecelMps2: input.baseDecelMps2,
                    uphillLoadMultiplier: input.uphillLoadMultiplier,
                    brakeFadeRisk: input.brakeFadeRisk,
                    weightTonnes: input.weightTonnes,
                    engineAccelCapMps2: input.engineAccelCapMps2
                ),
                deltaTime: 1.0 / 60.0
            )
            speed = step.newSpeedMps
        }

        #expect(speed > 4.0)
    }
}
