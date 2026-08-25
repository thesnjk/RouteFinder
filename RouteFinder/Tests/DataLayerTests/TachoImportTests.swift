import Contracts
import DataLayer
import Foundation
import Testing

@Test func dddImporterParsesSimpleJSONExport() async throws {
    let json = """
    {
      "remainingContinuousDriveSeconds": 7200,
      "remainingDailyDriveSeconds": 18000,
      "remainingWeeklyDriveSeconds": 140000,
      "cardNumber": "GB123456789012"
    }
    """.data(using: .utf8)!

    let importer = DDDImporter(now: { Date(timeIntervalSince1970: 1_700_000_000) })
    let summary = try await importer.importDriverCard(data: json)

    #expect(summary.remainingContinuousDriveSeconds == 7200)
    #expect(summary.remainingDailyDriveSeconds == 18000)
    #expect(summary.remainingWeeklyDriveSeconds == 140000)
    #expect(summary.cardNumber == "GB123456789012")
    #expect(summary.sourceFileName == "import")
}

@Test func dddImporterParsesRemainingDriveSecondsAlias() throws {
    let json = """
    {"remainingDriveSeconds": 3600, "remainingDailyDriveSeconds": 9000, "remainingWeeklyDriveSeconds": 50000}
    """.data(using: .utf8)!
    let importer = DDDImporter()
    let summary = try importer.importDriverCard(data: json, sourceFileName: "fixture.json")
    #expect(summary.remainingContinuousDriveSeconds == 3600)
    #expect(summary.sourceFileName == "fixture.json")
}

@Test func dddImporterRejectsUnrecognizedBinaryWithoutSidecar() {
    let binary = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0x76, 0x75])
    let importer = DDDImporter()
    #expect(throws: TachoImportError.unrecognizedBinaryDDD) {
        try importer.importDriverCard(data: binary, sourceFileName: "card.ddd")
    }
}

@Test func dddImporterUsesSidecarJSONForBinaryDDD() throws {
    let binary = Data([0x00, 0x01, 0x02, 0xFF, 0xFE])
    let sidecar = """
    {"remainingContinuousDriveSeconds": 1000, "remainingDailyDriveSeconds": 2000, "remainingWeeklyDriveSeconds": 3000}
    """.data(using: .utf8)!
    let importer = DDDImporter()
    let summary = try importer.importDriverCard(
        data: binary,
        sourceFileName: "card.ddd",
        sidecarData: sidecar
    )
    #expect(summary.remainingContinuousDriveSeconds == 1000)
    #expect(summary.remainingDailyDriveSeconds == 2000)
}

@Test func stubPartnerTachoPortThrowsNotConfigured() async {
    let stub = StubPartnerTachoPort()
    await #expect(throws: TachoImportError.partnerNotConfigured) {
        try await stub.fetchRemoteStatus()
    }
}

@Test func canIDriveEvaluatorUsesFreshImportedCard() {
    let imported = TachoCardSummary(
        remainingContinuousDriveSeconds: 500,
        remainingDailyDriveSeconds: 1000,
        remainingWeeklyDriveSeconds: 10_000,
        importedAt: Date(),
        sourceFileName: "card.json"
    )
    let clock = HosClockSnapshot(
        mode: .driving,
        remainingContinuousDriveSeconds: 0,
        remainingDailyDriveSeconds: 0,
        remainingWeeklyDriveSeconds: 0
    )
    let status = CanIDriveEvaluator.evaluate(imported: imported, clockSnapshot: clock)
    #expect(status.canDrive == true)
    #expect(status.usesImportedCard == true)
    #expect(status.remainingContinuousDriveSeconds == 500)
    #expect(status.reason.contains("tachograph"))
}

@Test func canIDriveEvaluatorFallsBackToClockWhenImportStale() {
    let imported = TachoCardSummary(
        remainingContinuousDriveSeconds: 5000,
        remainingDailyDriveSeconds: 5000,
        remainingWeeklyDriveSeconds: 10_000,
        importedAt: Date().addingTimeInterval(-25 * 3600),
        sourceFileName: "old.json"
    )
    let clock = HosClockSnapshot(
        mode: .driving,
        remainingContinuousDriveSeconds: 0,
        remainingDailyDriveSeconds: 1000,
        remainingWeeklyDriveSeconds: 10_000
    )
    let status = CanIDriveEvaluator.evaluate(imported: imported, clockSnapshot: clock)
    #expect(status.canDrive == false)
    #expect(status.usesImportedCard == false)
    #expect(status.reason.contains(HosRestInsertionResult.legalDisclaimer))
}

@Test func canIDriveEvaluatorRequiresBothContinuousAndDaily() {
    let clock = HosClockSnapshot(
        mode: .driving,
        remainingContinuousDriveSeconds: 100,
        remainingDailyDriveSeconds: 0,
        remainingWeeklyDriveSeconds: 10_000
    )
    let status = CanIDriveEvaluator.evaluate(imported: nil, clockSnapshot: clock)
    #expect(status.canDrive == false)
    #expect(status.usesImportedCard == false)
}
