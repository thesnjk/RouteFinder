import Contracts
import Foundation

/// Disk-backed DVSA walkaround inspection store for local records and sync queue.
public actor DiskInspectionStore: InspectionStorePort {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a store under Application Support (or a custom directory for tests).
    public init(storageDirectory: URL? = nil) {
        if let storageDirectory {
            directory = storageDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            directory = support.appendingPathComponent("RouteFinder/inspections", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Saves (or overwrites) an inspection record on disk.
    public func save(_ record: InspectionRecord) async throws {
        let url = recordURL(for: record.id)
        let data = try encoder.encode(record)
        try data.write(to: url, options: .atomic)
    }

    /// Marks the record as sync-pending and persists it.
    public func enqueueSync(_ record: InspectionRecord) async throws {
        var pending = record
        pending.syncPending = true
        try await save(pending)
    }

    /// Loads all saved inspection records, newest first.
    public func loadAll() async throws -> [InspectionRecord] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }

        var records: [InspectionRecord] = []
        for url in urls {
            let data = try Data(contentsOf: url)
            if let record = try? decoder.decode(InspectionRecord.self, from: data) {
                records.append(record)
            }
        }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    private func recordURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
