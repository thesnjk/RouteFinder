import Contracts
import CostModel
import Foundation
import Testing

@Test func poiConfidenceAdjusterLowersLaybyFullReports() {
    let poi = TruckPoi(
        id: "layby-1",
        kind: .layby,
        latitude: 51.5,
        longitude: -0.1,
        label: "Layby",
        confidence: 0.9
    )
    let report = CrowdReport(
        latitude: 51.5001,
        longitude: -0.1001,
        type: .laybyFull,
        reporterId: "driver-1",
        note: "layby-1"
    )
    let adjusted = PoiConfidenceAdjuster.adjust(pois: [poi], reports: [report])
    #expect((adjusted.first?.confidence ?? 1) < 0.9)
}

@Test func poiConfidenceAdjusterRaisesLaybySpacesReports() {
    let poi = TruckPoi(
        id: "layby-2",
        kind: .layby,
        latitude: 51.5,
        longitude: -0.1,
        label: "Layby",
        confidence: 0.7
    )
    let report = CrowdReport(
        latitude: 51.5001,
        longitude: -0.1001,
        type: .laybySpaces,
        reporterId: "driver-1",
        note: "layby-2"
    )
    let adjusted = PoiConfidenceAdjuster.adjust(pois: [poi], reports: [report])
    #expect((adjusted.first?.confidence ?? 0) > 0.7)
}

@Test func parkingOccupancyPriorUsesCrowdLaybyFullReport() {
    let stop = LaybyStop(
        id: "stop-full",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Busy layby",
        arcLengthAlongRouteMeters: 10_000
    )
    let report = LaybyOccupancyReport.make(
        stop: stop,
        kind: .full,
        reporterId: "driver-1"
    )
    let prior = ParkingOccupancyPrior.laybyOccupancyPrior(
        at: Date(),
        for: stop,
        reports: [report]
    )
    #expect(prior == .high)
}

@Test func parkingOccupancyPriorUsesCrowdLaybySpacesReport() {
    let stop = LaybyStop(
        id: "stop-spaces",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Open layby",
        arcLengthAlongRouteMeters: 10_000
    )
    let report = LaybyOccupancyReport.make(
        stop: stop,
        kind: .spacesAvailable,
        reporterId: "driver-1"
    )
    let prior = ParkingOccupancyPrior.laybyOccupancyPrior(
        at: Date(),
        for: stop,
        reports: [report]
    )
    #expect(prior == .low)
}

@Test func laybyPredictionEnginePrefersSpacesReportOverFullWhenEquidistant() {
    let fullStop = LaybyStop(
        id: "full",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Full",
        arcLengthAlongRouteMeters: 20_000
    )
    let openStop = LaybyStop(
        id: "open",
        coordinate: Coordinate(latitude: 51.51, longitude: -0.11),
        label: "Open",
        arcLengthAlongRouteMeters: 20_500
    )
    let reports = [
        LaybyOccupancyReport.make(stop: fullStop, kind: .full, reporterId: "d1"),
        LaybyOccupancyReport.make(stop: openStop, kind: .spacesAvailable, reporterId: "d1"),
    ]
    let input = LaybyPredictionInput(
        candidates: [fullStop, openStop],
        currentArcLengthMeters: 0,
        speedMps: 20,
        pathDurationsSeconds: [0, 1_000],
        pathArcLengthsMeters: [0, 40_000],
        remainingContinuousDriveSeconds: 4_500,
        now: Date(timeIntervalSince1970: 1_700_000_000),
        crowdReports: reports
    )
    let result = LaybyPredictionEngine.predict(input)
    #expect(result.primary?.stop.id == "open")
    #expect(result.primary?.occupancyPrior == .low)
}

@Test func crowdOccupancyPriorTwoRecentFullReportsYieldHigh() {
    let stop = LaybyStop(
        id: "multi-full",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Busy",
        arcLengthAlongRouteMeters: 10_000
    )
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let reports = [
        LaybyOccupancyReport.make(stop: stop, kind: .full, reporterId: "d1", createdAt: now.addingTimeInterval(-600)),
        LaybyOccupancyReport.make(stop: stop, kind: .full, reporterId: "d2", createdAt: now.addingTimeInterval(-120)),
    ]
    let prior = ParkingOccupancyPrior.crowdOccupancyPrior(for: stop, reports: reports, now: now)
    #expect(prior == .high)
}

@Test func crowdOccupancyPriorOldFullPlusRecentSpacesYieldsLow() {
    let stop = LaybyStop(
        id: "conflict",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Mixed",
        arcLengthAlongRouteMeters: 10_000
    )
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let reports = [
        LaybyOccupancyReport.make(
            stop: stop,
            kind: .full,
            reporterId: "d1",
            createdAt: now.addingTimeInterval(-6 * 3_600)
        ),
        LaybyOccupancyReport.make(
            stop: stop,
            kind: .spacesAvailable,
            reporterId: "d2",
            createdAt: now.addingTimeInterval(-300)
        ),
    ]
    let prior = ParkingOccupancyPrior.crowdOccupancyPrior(for: stop, reports: reports, now: now)
    #expect(prior == .low)
}

@Test func crowdOccupancyPriorStaleSingleReportFallsBackToNil() {
    let stop = LaybyStop(
        id: "stale",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Stale",
        arcLengthAlongRouteMeters: 10_000
    )
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let reports = [
        LaybyOccupancyReport.make(
            stop: stop,
            kind: .full,
            reporterId: "d1",
            createdAt: now.addingTimeInterval(-12 * 3_600)
        ),
    ]
    let prior = ParkingOccupancyPrior.crowdOccupancyPrior(for: stop, reports: reports, now: now)
    #expect(prior == nil)

    // Hour-of-day path still returns a prior when crowd signal is too weak.
    let fused = ParkingOccupancyPrior.laybyOccupancyPrior(at: now, for: stop, reports: reports)
    #expect(fused == .low || fused == .moderate || fused == .high)
}

@Test func latestOccupancySignalReturnsNewestKindAndTimestamp() {
    let stop = LaybyStop(
        id: "signal",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Signal",
        arcLengthAlongRouteMeters: 10_000
    )
    let older = Date(timeIntervalSince1970: 1_700_000_000)
    let newer = older.addingTimeInterval(1_800)
    let reports = [
        LaybyOccupancyReport.make(stop: stop, kind: .full, reporterId: "d1", createdAt: older),
        LaybyOccupancyReport.make(stop: stop, kind: .spacesAvailable, reporterId: "d2", createdAt: newer),
    ]
    let signal = ParkingOccupancyPrior.latestOccupancySignal(for: stop, reports: reports)
    #expect(signal?.kind == .spacesAvailable)
    #expect(signal?.createdAt == newer)
}

@Test func laybyPredictionEnginePopulatesLastOccupancyFields() {
    let stop = LaybyStop(
        id: "last-seen",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Last seen",
        arcLengthAlongRouteMeters: 15_000
    )
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let report = LaybyOccupancyReport.make(
        stop: stop,
        kind: .full,
        reporterId: "d1",
        createdAt: createdAt
    )
    let input = LaybyPredictionInput(
        candidates: [stop],
        currentArcLengthMeters: 0,
        speedMps: 20,
        pathDurationsSeconds: [0, 1_000],
        pathArcLengthsMeters: [0, 40_000],
        remainingContinuousDriveSeconds: 4_500,
        now: createdAt,
        crowdReports: [report]
    )
    let primary = LaybyPredictionEngine.predict(input).primary
    #expect(primary?.lastOccupancyKind == .full)
    #expect(primary?.lastOccupancyReportAt == createdAt)
}

@Test func laybyPredictionEngineBreakNowRanksNearestAhead() {
    let near = LaybyStop(
        id: "near",
        coordinate: Coordinate(latitude: 51.5, longitude: -0.1),
        label: "Near layby",
        arcLengthAlongRouteMeters: 2_000
    )
    let far = LaybyStop(
        id: "far",
        coordinate: Coordinate(latitude: 51.51, longitude: -0.11),
        label: "Far layby",
        arcLengthAlongRouteMeters: 20_000
    )
    let input = LaybyPredictionInput(
        candidates: [far, near],
        currentArcLengthMeters: 500,
        speedMps: 20,
        pathDurationsSeconds: [0, 2_000],
        pathArcLengthsMeters: [0, 40_000]
    )
    let result = LaybyPredictionEngine.predictBreakNow(input)
    #expect(result.primary?.stop.id == "near")
    #expect(result.primary?.reasonCodes.contains(.breakNow) == true)
}

@Test func maneuverSpeechFormatterSpokenLanePhraseUsesLeftTwoLanes() {
    let guidance = LaneGuidance(
        lanes: [.straight, .straight, .right],
        recommendedIndices: [0, 1]
    )
    #expect(ManeuverSpeechFormatter.spokenLanePhrase(for: guidance) == "Use the left two lanes")
}

@Test func maneuverSpeechFormatterPrepareTierIncludesLaneHint() {
    let instruction = TurnInstruction(
        id: UUID(),
        maneuver: .right,
        roadName: "A1",
        distance: 400,
        bearing: 90,
        laneGuidance: LaneGuidance(lanes: [.straight, .right], recommendedIndices: [1])
    )
    let prompt = ManeuverSpeechFormatter.spokenPrompt(for: instruction, tier: .prepare)
    #expect(prompt.contains("right lane"))
}
