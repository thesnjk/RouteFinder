import Contracts
import DataLayer
import Foundation
import Testing

@Test func telematicsCSVImporterParsesGeotabStyleHeaders() throws {
    let csv = """
    Device,Latitude,Longitude,DateTime,Speed
    Artic 1,52.6309,1.2974,2026-09-15T10:00:00Z,64
    Artic 2,53.4808,-2.2426,2026-09-15T10:05:00Z,48
    """
    let pings = try TelematicsCSVImporter.parse(csv: csv, defaultProvider: .geotab)
    #expect(pings.count == 2)
    #expect(pings[0].vehicleLabel == "Artic 1")
    #expect(pings[0].latitude == 52.6309)
    #expect(pings[0].provider == .geotab)
    #expect(pings[1].speedKph == 48)
}

@Test func telematicsCSVImporterRejectsMissingColumns() {
    let csv = "Name,Foo\nA,1\n"
    #expect(throws: TelematicsCSVImporterError.missingRequiredColumns) {
        try TelematicsCSVImporter.parse(csv: csv)
    }
}

@Test func telematicsImportStoreRoundTrip() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("TelematicsStore-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = TelematicsImportStore(directory: dir)
    let batch = TelematicsImportBatch(
        pings: [
            TelematicsVehiclePing(
                provider: .samsara,
                vehicleLabel: "Unit 9",
                latitude: 51.5,
                longitude: -0.1,
                recordedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
        ],
        sourceFileName: "export.csv"
    )
    try await store.save(batch)
    let loaded = await store.load()
    #expect(loaded?.pings.count == 1)
    #expect(loaded?.pings.first?.vehicleLabel == "Unit 9")
    #expect(loaded?.sourceFileName == "export.csv")
}

@Test func fleetTelematicsIngestPersists() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FleetTelematics-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = DiskFleetStore(storageDirectory: dir)
    let vehicleId = UUID()
    let ping = try await store.ingestTelematics(
        TelematicsIngestRequest(
            vehicleId: vehicleId,
            latitude: 52.1,
            longitude: 0.5,
            recordedAt: Date(timeIntervalSince1970: 1_720_000_000),
            provider: "geotab",
            vehicleLabel: "Artic HTTP"
        )
    )
    #expect(ping.provider == .geotab)
    #expect(ping.vehicleLabel == "Artic HTTP")
    let latest = try await store.latestTelematicsPings()
    #expect(latest.count == 1)
}
