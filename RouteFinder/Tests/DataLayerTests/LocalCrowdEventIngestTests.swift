import Contracts
import DataLayer
import Foundation
import Testing

@Test func localCrowdEventIngestPersistsReportsAcrossInstances() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RouteFinderCrowdTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let stop = LaybyStop(
        id: "persist-1",
        coordinate: Coordinate(latitude: 52.0, longitude: -1.0),
        label: "Persisted",
        arcLengthAlongRouteMeters: 5_000
    )
    let report = LaybyOccupancyReport.make(stop: stop, kind: .full, reporterId: "driver")

    let first = LocalCrowdEventIngest(storageDirectory: directory)
    try await first.submit(report)
    let loaded = await first.allReports()
    #expect(loaded.contains { $0.id == report.id })

    let second = LocalCrowdEventIngest(storageDirectory: directory)
    let reloaded = await second.allReports()
    #expect(reloaded.contains { $0.id == report.id && $0.type == .laybyFull })
}
