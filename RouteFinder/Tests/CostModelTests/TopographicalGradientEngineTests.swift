import Contracts
import CostModel
import Testing

@Suite("Topographical Gradient Engine")
struct TopographicalGradientEngineTests {
    @Test("Uphill grade reduces effective acceleration")
    func uphillThrottle() {
        let base = 1.2
        let gradePercent = 8.0
        let effective = TopographicalGradientEngine.effectiveMaxAccelerationMps2(
            maxAccelerationMps2: base,
            gradePercent: gradePercent
        )
        #expect(effective < base)
    }

    @Test("Sustained downhill crosses thermal threshold")
    func thermalThreshold() {
        var engine = TopographicalGradientEngine()
        var state = TopographyGradientState(
            gradeAngleDegrees: -4,
            effectiveMaxAccelerationMps2: 1.0,
            thermalLoadJoules: 0
        )
        for _ in 0..<500 {
            state = engine.advanceThermalLoad(
                gradePercent: -6.0,
                velocityMps: 16.7,
                massKg: 44_000,
                deltaTime: 0.033
            )
        }
        #expect(state.thermalLoadJoules > TopographicalGradientEngine.elevatedThermalLoadJoules)
    }
}

@Suite("Predictive Telemetry Service")
struct PredictiveTelemetryServiceTests {
    @Test("Efficiency index penalizes harsh events")
    func efficiencyScoring() {
        let events = [
            SimulationEvent(kind: .hardDeceleration, arcLengthMeters: 100, elapsedSeconds: 10, magnitude: 4.0),
            SimulationEvent(kind: .tireSlip, arcLengthMeters: 200, elapsedSeconds: 20, magnitude: 5.0),
        ]
        let report = PredictiveTelemetryService.generateReport(
            staticWebETASeconds: 3600,
            kineticPhysicsETASeconds: 3800,
            events: events,
            thermalFadeIntegral: 1_000_000,
            lateralGExcessSeconds: 5,
            peakBrakeFadeRisk: nil,
            vehicleWeightTonnes: 44
        )
        #expect(report.brakeWearKineticEfficiencyIndex < 100)
        #expect(report.brakeWearKineticEfficiencyIndex >= 0)
        #expect(report.hardDecelEventCount == 1)
    }

    @Test("Insurance savings appear above threshold index")
    func insuranceSavings() {
        let report = PredictiveTelemetryService.generateReport(
            staticWebETASeconds: 3600,
            kineticPhysicsETASeconds: 3700,
            events: [],
            thermalFadeIntegral: 0,
            lateralGExcessSeconds: 0,
            peakBrakeFadeRisk: nil,
            vehicleWeightTonnes: 44
        )
        #expect(report.brakeWearKineticEfficiencyIndex >= 70)
        #expect(report.estimatedPremiumSavingsGBP > 0)
    }
}
