import Contracts
import Foundation

/// In-memory + disk-backed crowd event ingest that scores reports and retains them for POI confidence.
public actor LocalCrowdEventIngest: CrowdEventIngestPort {
    private var reports: [String: CrowdReport] = [:]
    private var scores: [String: Double] = [:]
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// Reports older than this are dropped on load/save.
    public static let maxAgeSeconds: TimeInterval = 24 * 3600

    /// Creates an ingest store under Application Support (or a custom directory for tests).
    public init(storageDirectory: URL? = nil) {
        if let storageDirectory {
            directory = storageDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            directory = support.appendingPathComponent("RouteFinder/crowd-reports", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Eager load from disk before first await (actor init is isolated).
        let loaded = Self.loadReports(from: directory, decoder: decoder)
        for report in loaded {
            reports[report.id] = report
        }
    }

    public func submit(_ report: CrowdReport) async throws {
        reports[report.id] = report
        try persist()
    }

    public func score(reportId: String, inputs: CrowdConfidenceInputs) async -> Double {
        let value = CrowdEventBus.confidenceScore(inputs: inputs)
        scores[reportId] = value
        return value
    }

    /// Returns submitted crowd reports that are still within the retention window.
    public func allReports(now: Date = Date()) -> [CrowdReport] {
        prune(now: now)
        return Array(reports.values).sorted { $0.createdAt > $1.createdAt }
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.maxAgeSeconds)
        let stale = reports.values.filter { $0.createdAt < cutoff }.map(\.id)
        guard !stale.isEmpty else { return }
        for id in stale {
            reports.removeValue(forKey: id)
            scores.removeValue(forKey: id)
        }
        try? persist()
    }

    private func persist() throws {
        let url = directory.appendingPathComponent("reports.json")
        let payload = Array(reports.values)
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    private static func loadReports(from directory: URL, decoder: JSONDecoder) -> [CrowdReport] {
        let url = directory.appendingPathComponent("reports.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([CrowdReport].self, from: data) else {
            return []
        }
        let cutoff = Date().addingTimeInterval(-maxAgeSeconds)
        return decoded.filter { $0.createdAt >= cutoff }
    }
}
