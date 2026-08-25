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
