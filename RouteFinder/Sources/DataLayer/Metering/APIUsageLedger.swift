import Contracts
import Foundation

/// On-device ledger of external API calls with daily roll-up and soft budget guards.
public actor APIUsageLedger {
    /// Shared process-wide ledger persisted under Application Support.
    public static let shared = APIUsageLedger()

    private struct PersistedDay: Codable, Sendable {
        var dayKey: String
        var counts: [String: Int]
    }

    private let calendar: Calendar
    private let storageURL: URL
    private var countsByDay: [String: [APIUsageProvider: Int]] = [:]
    private var didLoadFromDisk = false
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a ledger with optional custom storage for tests.
    public init(storageURL: URL? = nil, calendar: Calendar = .current) {
        self.calendar = calendar
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.storageURL = support
                .appendingPathComponent("RouteFinder/metering", isDirectory: true)
                .appendingPathComponent("api-usage.json")
        }
        try? FileManager.default.createDirectory(
            at: self.storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func ensureLoaded() {
        guard !didLoadFromDisk else { return }
        didLoadFromDisk = true
        loadFromDisk()
    }

    /// Records one completed request for the provider on today's calendar day.
    public func record(provider: APIUsageProvider, at date: Date = Date()) {
        ensureLoaded()
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        var dayCounts = countsByDay[dayKey, default: [:]]
        dayCounts[provider, default: 0] += 1
        countsByDay[dayKey] = dayCounts
        persist()
    }

    /// Request count for a provider on the given day.
    public func count(provider: APIUsageProvider, on date: Date = Date()) -> Int {
        ensureLoaded()
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return countsByDay[dayKey]?[provider] ?? 0
    }

    /// Rolled-up summary for the given calendar day.
    public func summary(on date: Date = Date()) -> APIUsageDaySummary {
        ensureLoaded()
        let dayKey = Self.dayKey(for: date, calendar: calendar)
        return APIUsageDaySummary(dayKey: dayKey, counts: countsByDay[dayKey] ?? [:])
    }

    /// Whether today's count meets or exceeds the provider soft budget.
    public func isOverSoftBudget(provider: APIUsageProvider, on date: Date = Date()) -> Bool {
        summary(on: date).isOverSoftBudget(for: provider)
    }

    /// Returns `false` when non-critical polls should be skipped for budget protection.
    public func allowsNonCriticalRequest(provider: APIUsageProvider, on date: Date = Date()) -> Bool {
        guard provider.isNonCriticalPoll else { return true }
        return !isOverSoftBudget(provider: provider, on: date)
    }

    /// User-facing banner when any non-critical provider is over budget.
    public func budgetBannerMessage(on date: Date = Date()) -> String? {
        let summary = summary(on: date)
        let overBudget = APIUsageProvider.allCases.filter { provider in
            provider.isNonCriticalPoll && summary.isOverSoftBudget(for: provider)
        }
        guard !overBudget.isEmpty else { return nil }
        let names = overBudget.map(\.displayName).joined(separator: ", ")
        return "API soft budget reached for \(names). Background traffic and roadworks polls are paused until tomorrow."
    }

    /// Replaces in-memory state (for tests).
    public func replaceAllCounts(_ countsByDay: [String: [APIUsageProvider: Int]]) {
        ensureLoaded()
        self.countsByDay = countsByDay
        persist()
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let persisted = try? decoder.decode([PersistedDay].self, from: data) else {
            return
        }
        countsByDay = Dictionary(
            uniqueKeysWithValues: persisted.compactMap { day in
                var mapped: [APIUsageProvider: Int] = [:]
                for (raw, count) in day.counts {
                    guard let provider = APIUsageProvider(rawValue: raw) else { continue }
                    mapped[provider] = count
                }
                return (day.dayKey, mapped)
            }
        )
    }

    private func persist() {
        let payload = countsByDay.map { dayKey, counts in
            PersistedDay(
                dayKey: dayKey,
                counts: Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })
            )
        }
        .sorted { $0.dayKey < $1.dayKey }
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
