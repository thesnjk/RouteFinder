import Foundation

/// Builds crowd reports for driver layby occupancy feedback.
public enum LaybyOccupancyReport: Sendable {
    /// Occupancy observation from the driver.
    public enum Kind: String, Sendable, Hashable, Codable, CaseIterable {
        case full
        case spacesAvailable
    }

    /// Creates a crowd report anchored to a layby stop (POI id stored in `note`).
    public static func make(
        stop: LaybyStop,
        kind: Kind,
        reporterId: String,
        createdAt: Date = Date()
    ) -> CrowdReport {
        CrowdReport(
            latitude: stop.coordinate.latitude,
            longitude: stop.coordinate.longitude,
            type: kind == .full ? .laybyFull : .laybySpaces,
            reporterId: reporterId,
            createdAt: createdAt,
            note: stop.id
        )
    }
}
