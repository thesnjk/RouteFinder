import Foundation

/// A closed time interval for Vroom job or break scheduling.
public struct TimeWindow: Codable, Equatable, Sendable, Hashable {
    /// Inclusive start instant.
    public let start: Date
    /// Inclusive end instant.
    public let end: Date

    /// Creates a time window with start and end dates.
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// Creates a time window from a closed date range.
    public init(_ range: ClosedRange<Date>) {
        self.start = range.lowerBound
        self.end = range.upperBound
    }

    /// Closed range representation for scheduling logic.
    public var closedRange: ClosedRange<Date> {
        start ... end
    }

    /// Duration of the window in seconds.
    public var durationSeconds: TimeInterval {
        end.timeIntervalSince(start)
    }

    /// Converts the window to Vroom time-window seconds from a reference midnight UTC.
    public func vroomSeconds(from referenceMidnight: Date) -> [Int] {
        let startSec = Int(start.timeIntervalSince(referenceMidnight))
        let endSec = Int(end.timeIntervalSince(referenceMidnight))
        return [max(0, startSec), max(startSec, endSec)]
    }
}
