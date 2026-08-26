import Contracts
import Foundation
import Testing

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

@Test func tripBriefFormatterIncludesStopListAndCompanyBreaks() {
    let allocation = CompanyBreakAllocation.demoAfternoonBreak()
    let context = TripBriefContext(
        stops: [
            TripBriefStop(label: "Felixstowe Port", role: "origin"),
            TripBriefStop(label: "Manchester Depot", role: "destination"),
        ],
        companyBreaks: [allocation]
    )
    let text = TripBriefFormatter.plainText(from: context)
    #expect(text.contains("Stops"))
    #expect(text.contains("Felixstowe Port"))
    #expect(text.contains("Company break windows"))
    #expect(text.contains("not legal tacho"))
}

@Test func tripBriefFormatterIncludesLaybySection() {
    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "layby-1",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "M1 J15 Layby"
        ),
        distanceRemainingMeters: 8_000,
        estimatedArrivalSeconds: 2_400,
        confidence: 0.8,
        occupancyPrior: .moderate,
        breakWindowOpensAt: Date(timeIntervalSince1970: 1_700_000_000),
        reasonCodes: [.physicsStress],
        isAdvisory: true
    )
    let text = TripBriefFormatter.plainText(from: TripBriefContext(laybyAdvisory: layby))
    #expect(text.contains("Predicted layby"))
    #expect(text.contains("M1 J15 Layby"))
    #expect(text.contains("moderate"))
}

@Test func tripBriefContextFromFleetTripMapsSnapshotFields() {
    let trip = FleetTrip(
        orgId: UUID(),
        vehicleId: UUID(),
        status: .rehearsed,
        stops: [
            FleetTripStop(sequence: 0, label: "Port", latitude: 51.95, longitude: 1.35, role: .origin),
            FleetTripStop(sequence: 1, label: "Depot", latitude: 53.48, longitude: -2.24, role: .destination),
        ],
        physicsETASeconds: 9_900,
        companyBreaks: [CompanyBreakAllocation.demoAfternoonBreak()]
    )
    let context = TripBriefContext.from(fleetTrip: trip, vehicleLabel: "Artic 1")
    #expect(context.stops.count == 2)
    #expect(context.physicsETASeconds == 9_900)
    #expect(context.vehicleLabel == "Artic 1")
    #expect(context.tripStatus == "Rehearsed")
    #expect(context.companyBreaks.count == 1)
}
