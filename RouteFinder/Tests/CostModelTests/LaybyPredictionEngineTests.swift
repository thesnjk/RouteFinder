import Contracts
import CostModel
import Foundation
import Testing

private func layby(id: String, arc: Double, label: String = "Layby") -> LaybyStop {
    LaybyStop(
        id: id,
        coordinate: Coordinate(latitude: 52.0, longitude: -1.0),
        label: label,
        arcLengthAlongRouteMeters: arc
    )
}

@Test func laybyPredictionHOSPrefersLastFeasibleNotFirstAhead() {
    let candidates = [
        layby(id: "near", arc: 5_000, label: "Near layby"),
        layby(id: "far", arc: 45_000, label: "Far layby"),
        layby(id: "too-late", arc: 200_000, label: "Too late layby"),
    ]
    let durations = Array(repeating: 600.0, count: 100)
    let arcs = (1...100).map { Double($0) * 2_000 }

    let input = LaybyPredictionInput(
        candidates: candidates,
        currentArcLengthMeters: 0,
        speedMps: 25,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        remainingContinuousDriveSeconds: 4.5 * 3600,
        remainingDailyDriveSeconds: 9 * 3600
    )

    let result = LaybyPredictionEngine.predict(input)
    let primary = try! #require(result.primary)
    #expect(primary.stop.id == "far")
    #expect(primary.reasonCodes.contains(.hosDeadline))
    #expect(primary.isAdvisory)
}

@Test func laybyPredictionCompanyWindowTighterThanHOS() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 13, minute: 0))!
    let windowStart = calendar.date(byAdding: .hour, value: 1, to: now)!
    let windowEnd = calendar.date(byAdding: .hour, value: 2, to: now)!

    let candidates = [
        layby(id: "early", arc: 10_000),
        layby(id: "mid", arc: 30_000),
        layby(id: "late", arc: 120_000),
    ]
    let durations = Array(repeating: 300.0, count: 60)
    let arcs = (1...60).map { Double($0) * 2_500 }

    let input = LaybyPredictionInput(
        candidates: candidates,
        currentArcLengthMeters: 0,
        speedMps: 20,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        remainingContinuousDriveSeconds: 5 * 3600,
        remainingDailyDriveSeconds: 9 * 3600,
        companyBreaks: [
            CompanyBreakAllocation(
                window: TimeWindow(start: windowStart, end: windowEnd),
                durationSeconds: 45 * 60,
                label: "Company break"
            ),
        ],
        now: now
    )

    let primary = try! #require(LaybyPredictionEngine.predict(input).primary)
    #expect(primary.stop.id == "mid")
    #expect(primary.reasonCodes.contains(.companyWindow))
    #expect(primary.breakWindowOpensAt == windowStart)
}

@Test func laybyPredictionPhysicsPullsUpstreamOfHighGrade() {
    let candidates = [
        layby(id: "before-grade", arc: 18_000),
        layby(id: "on-grade", arc: 40_000),
        layby(id: "after-grade", arc: 55_000),
    ]
    let durations = Array(repeating: 500.0, count: 20)
    let arcs = (1...20).map { Double($0) * 3_000 }
    let stress = (0..<20).map { index in
        if index == 12 {
            SegmentKineticStress(gradePercentage: 8.0, thermalStressScore: 0.1, loadMultiplier: 1.2)
        } else {
            SegmentKineticStress.neutral
        }
    }

    let input = LaybyPredictionInput(
        candidates: candidates,
        currentArcLengthMeters: 0,
        speedMps: 22,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        remainingContinuousDriveSeconds: 4 * 3600,
        remainingDailyDriveSeconds: 9 * 3600,
        kineticStress: stress
    )

    let primary = try! #require(LaybyPredictionEngine.predict(input).primary)
    #expect(primary.stop.id == "before-grade")
    #expect(primary.reasonCodes.contains(.physicsStress))
}

@Test func laybyPredictionEveningOccupancyDownranksBusyLayby() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 16, minute: 0))!

    let candidates = [
        layby(id: "a", arc: 90_500, label: "Busy evening layby"),
        layby(id: "b", arc: 90_000, label: "Alternate layby"),
    ]
    let durations = Array(repeating: 400.0, count: 30)
    let arcs = (1...30).map { Double($0) * 3_000 }

    let input = LaybyPredictionInput(
        candidates: candidates,
        currentArcLengthMeters: 0,
        speedMps: 25,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        remainingContinuousDriveSeconds: 3 * 3600,
        remainingDailyDriveSeconds: 9 * 3600,
        now: now
    )

    let primary = try! #require(LaybyPredictionEngine.predict(input).primary)
    #expect(primary.stop.id == "b")
    #expect(primary.occupancyPrior != .high || primary.reasonCodes.contains(.occupancy))
}

@Test func laybyPredictionNoHOSOrCompanyUsesGeometryFallback() {
    let candidates = [
        layby(id: "first", arc: 2_000),
        layby(id: "second", arc: 8_000),
    ]
    let input = LaybyPredictionInput(
        candidates: candidates,
        currentArcLengthMeters: 0,
        speedMps: 20
    )
    let primary = try! #require(LaybyPredictionEngine.predict(input).primary)
    #expect(primary.stop.id == "first")
    #expect(primary.reasonCodes.contains(.geometryFallback))
    #expect(primary.confidence < 0.5)
    #expect(!primary.isAdvisory)
}

@Test func laybyPredictionSkippedIdsAdvanceToNextCandidate() {
    let candidates = [
        layby(id: "a", arc: 5_000),
        layby(id: "b", arc: 45_000),
    ]
    let durations = Array(repeating: 600.0, count: 100)
    let arcs = (1...100).map { Double($0) * 2_000 }
    let input = LaybyPredictionInput(
        candidates: candidates,
        skippedIds: ["a"],
        currentArcLengthMeters: 0,
        speedMps: 25,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        remainingContinuousDriveSeconds: 4.5 * 3600
    )
    let primary = try! #require(LaybyPredictionEngine.predict(input).primary)
    #expect(primary.stop.id == "b")
}

@Test func parkingOccupancyPriorLaybyEveningIsHigh() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let evening = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 19))!
    #expect(ParkingOccupancyPrior.laybyOccupancyPrior(at: evening, calendar: calendar) == .high)
}
