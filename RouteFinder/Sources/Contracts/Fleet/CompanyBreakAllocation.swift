import Foundation

/// Company-allocated mandatory break window for fleet trip planning.
///
/// This is a **company policy / planning aid** aligned with dispatch schedules.
/// It does **not** replace the legal digital tachograph or vehicle unit record.
public struct CompanyBreakAllocation: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: UUID
    /// Window during which the break may be taken.
    public var window: TimeWindow
    /// Required break duration in seconds.
    public var durationSeconds: TimeInterval
    /// Optional dispatch label (e.g. "Afternoon break").
    public var label: String?

    /// Creates a company break allocation.
    public init(
        id: UUID = UUID(),
        window: TimeWindow,
        durationSeconds: TimeInterval,
        label: String? = nil
    ) {
        self.id = id
        self.window = window
        self.durationSeconds = durationSeconds
        self.label = label
    }

    /// Demo UK afternoon break window for Felixstowe→Manchester seed jobs.
    public static func demoAfternoonBreak(reference: Date = Date()) -> CompanyBreakAllocation {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = 14
        components.minute = 20
        var start = calendar.date(from: components) ?? reference
        components.hour = 15
        components.minute = 30
        var end = calendar.date(from: components) ?? start.addingTimeInterval(70 * 60)
        if end <= reference {
            start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return CompanyBreakAllocation(
            window: TimeWindow(start: start, end: end),
            durationSeconds: 45 * 60,
            label: "Afternoon break"
        )
    }
}
