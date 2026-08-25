import Contracts
import Foundation

/// In-memory crowd event ingest that scores reports and retains them for POI confidence.
public actor LocalCrowdEventIngest: CrowdEventIngestPort {
    private var reports: [String: CrowdReport] = [:]
    private var scores: [String: Double] = [:]

    public init() {}

    public func submit(_ report: CrowdReport) async throws {
        reports[report.id] = report
    }

    public func score(reportId: String, inputs: CrowdConfidenceInputs) async -> Double {
        let value = CrowdEventBus.confidenceScore(inputs: inputs)
        scores[reportId] = value
        return value
    }

    /// Returns all submitted crowd reports.
    public func allReports() -> [CrowdReport] {
        Array(reports.values)
    }
}
