import Contracts
import DataLayer
import Foundation
import Testing

@Test func diskInspectionStoreSaveAndLoad() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("RF-Inspection-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = DiskInspectionStore(storageDirectory: dir)
    var record = InspectionRecord(
        vehicleLabel: "Artic 1",
        registrationPlate: "AB12 CDE"
    )
    record.items[0].status = .pass
    try await store.save(record)

    let loaded = try await store.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded.first?.id == record.id)
    #expect(loaded.first?.items.first?.status == .pass)

    try await store.enqueueSync(record)
    let pending = try await store.loadAll()
    #expect(pending.first?.syncPending == true)
}

@Test func diskFleetStorePersistsTripAcrossInstances() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("RF-Fleet-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = DiskFleetStore(storageDirectory: dir)
    let seeded = try await store.seedDemoThreeStopJob()
    #expect(seeded.trip.stops.count == 3)

    let reloaded = DiskFleetStore(storageDirectory: dir)
    let active = try await reloaded.activeTrip(forVehicleId: seeded.vehicle.id)
    #expect(active?.id == seeded.trip.id)
    #expect(active?.stops.count == 3)
    #expect(active?.stops.map(\.label) == ["Felixstowe Port", "Midlands Hub", "Manchester Depot"])
}
