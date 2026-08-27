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
