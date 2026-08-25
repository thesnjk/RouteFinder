import Contracts
import CostModel
import DataLayer
import Foundation
import Testing

@Test func eu561HosClockTransitionsUpdateRemainingTimes() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    final class ClockBox: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }
    let box = ClockBox(start)
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("hos-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let clock = EU561HosClock(storageDirectory: dir, now: { box.now })
    _ = try await clock.transition(mode: HosDutyEvent(mode: .driving, at: start))

    box.now = start.addingTimeInterval(30 * 60)
    let snap = await clock.snapshot()
    #expect(snap.mode == .driving)
    #expect(abs(snap.remainingContinuousDriveSeconds - (EU561HosClock.continuousDriveLimitSeconds - 1800)) < 1.5)
    #expect(abs(snap.remainingDailyDriveSeconds - (EU561HosClock.dailyDriveLimitSeconds - 1800)) < 1.5)

    box.now = start.addingTimeInterval(45 * 60)
    _ = try await clock.transition(mode: HosDutyEvent(mode: .breakRest, at: box.now))
    let afterBreak = await clock.snapshot()
    #expect(afterBreak.mode == .breakRest)
    #expect(abs(afterBreak.remainingContinuousDriveSeconds - EU561HosClock.continuousDriveLimitSeconds) < 1.5)
}

@Test func eu561HosForecastIncludesDisclaimer() async {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("hos-forecast-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let clock = EU561HosClock(storageDirectory: dir)
    let path = Array(repeating: TimeInterval(3600), count: 6) // 6 h > 4.5 h
    let result = await clock.forecast(pathDurationsSeconds: path)
    #expect(result.summary.contains(HosRestInsertionResult.legalDisclaimer))
    #expect(!result.insertions.isEmpty)
    #expect(HosRestInsertionResult.legalDisclaimer.contains("tachograph"))
}

@Test func hosRestInserterPrefersUpstreamOfHighGradeStress() {
    let durations: [TimeInterval] = [1800, 1800, 1800, 1800] // 2 h total; budget 1 h → deadline at index 1
    let arcs: [Double] = [10_000, 20_000, 30_000, 40_000]
    let stress = [
        SegmentKineticStress.neutral,
        SegmentKineticStress(gradePercentage: 8, thermalStressScore: 0.8, loadMultiplier: 1.4),
        SegmentKineticStress.neutral,
        SegmentKineticStress.neutral,
    ]
    let layby = TruckPoi(
        id: "layby-1",
        kind: .layby,
        latitude: 51.5,
        longitude: -0.1,
        label: "Test Layby",
        arcLengthAlongRouteMeters: 8_000
    )
    let insertions = HosRestInserter.insertions(
        remainingContinuousDriveSeconds: 3600,
        pathDurationsSeconds: durations,
        pathArcLengthsMeters: arcs,
        upcomingTruckPois: [layby],
        kineticStress: stress
    )
    #expect(insertions.count == 1)
    #expect(insertions[0].physicsPreferred == true)
    #expect(insertions[0].poiId == "layby-1")
    #expect(insertions[0].afterSegmentIndex < 1)
}

@Test func inMemoryDriverAlertBusPublishesHosAlerts() async {
    let bus = InMemoryDriverAlertBus()
    await bus.publish(
        DriverAlert(kind: .hos, title: "Break due", message: HosRestInsertionResult.legalDisclaimer)
    )
    let recent = await bus.recentAlerts()
    #expect(recent.count == 1)
    #expect(recent[0].kind == .hos)
    #expect(recent[0].message.contains("tachograph"))
}
