import Foundation

/// Driver break scheduling rule for Vroom vehicle optimization.
public struct OptimizationBreakRule: Codable, Equatable, Sendable, Hashable {
    /// Unique break identifier.
    public let id: Int
    /// Time windows during which the break may be taken.
    public let timeWindows: [TimeWindow]
    /// Required break duration in seconds.
    public let serviceDurationSeconds: Int
    /// Maximum continuous driving duration before break is mandatory.
    public let maxDrivingDurationSeconds: Int?

    /// Creates a break rule for route optimization.
    public init(
        id: Int,
        timeWindows: [TimeWindow],
        serviceDurationSeconds: Int,
        maxDrivingDurationSeconds: Int? = nil
    ) {
        self.id = id
        self.timeWindows = timeWindows
        self.serviceDurationSeconds = serviceDurationSeconds
        self.maxDrivingDurationSeconds = maxDrivingDurationSeconds
    }
}
