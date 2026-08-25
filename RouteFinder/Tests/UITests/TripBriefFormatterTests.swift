import Contracts
import Testing
@testable import UI

@Test func tripBriefFormatterIncludesKineticETAAndEfficiency() {
    let report = PredictiveTelemetryReport(
        staticWebETASeconds: 3600,
        kineticPhysicsETASeconds: 4200,
        brakeWearKineticEfficiencyIndex: 72,
        estimatedPremiumSavingsGBP: 150,
        hardDecelEventCount: 2,
        brakeFadeRiskEventCount: 1,
        lateralGViolationCount: 0,
        tireSlipEventCount: 1,
        brakeFadeRiskState: .elevated,
        events: []
    )

    let text = TripBriefFormatter.plainText(from: report)
    #expect(text.contains("RouteFinder Trip Brief"))
    #expect(text.contains("Physics kinetic ETA"))
    #expect(text.contains("72"))
    #expect(text.contains("£150"))
}
<<<<<<< HEAD

@Test func tripBriefFormatterIncludesHosSummaryAndDisclaimer() {
    let report = PredictiveTelemetryReport(
        staticWebETASeconds: 3600,
        kineticPhysicsETASeconds: 4200,
        brakeWearKineticEfficiencyIndex: 80,
        estimatedPremiumSavingsGBP: 0,
        hardDecelEventCount: 0,
        brakeFadeRiskEventCount: 0,
        lateralGViolationCount: 0,
        tireSlipEventCount: 0,
        brakeFadeRiskState: nil,
        events: []
    )
    let hos = HosRestInsertionResult(
        remainingContinuousDriveSeconds: 3600,
        remainingDailyDriveSeconds: 20_000,
        insertions: [],
        summary: "Continuous remaining 1h 0m. \(HosRestInsertionResult.legalDisclaimer)"
    )
    let text = TripBriefFormatter.plainText(from: report, hosForecast: hos)
    #expect(text.contains("Hours of service (advisory)"))
    #expect(text.contains(HosRestInsertionResult.legalDisclaimer))
}
=======
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
