import Foundation

/// External API providers tracked for daily unit-economics metering.
public enum APIUsageProvider: String, Codable, Sendable, CaseIterable, Hashable {
    case orsRoute
    case orsGeocode
    case orsMatrix
    case tomTomFlow
    case overpass
    case openWeather
    case regCheck
    case dvla

    /// Human-readable label for Settings and diagnostics.
    public var displayName: String {
        switch self {
        case .orsRoute: "ORS routing"
        case .orsGeocode: "ORS geocoding"
        case .orsMatrix: "ORS matrix"
        case .tomTomFlow: "TomTom traffic"
        case .overpass: "Overpass roadworks"
        case .openWeather: "OpenWeather"
        case .regCheck: "RegCheck"
        case .dvla: "DVLA"
        }
    }

    /// Whether background polls for this provider may be skipped when over the soft budget.
    public var isNonCriticalPoll: Bool {
        switch self {
        case .tomTomFlow, .overpass:
            true
        case .orsRoute, .orsGeocode, .orsMatrix, .openWeather, .regCheck, .dvla:
            false
        }
    }
}

/// Documented free-tier soft limit for a provider (requests per calendar day).
public struct APIUsageBudget: Sendable, Equatable {
    /// Inclusive soft daily request cap before non-critical polls are skipped.
    public let softDailyLimit: Int

    /// Creates a soft budget with the given daily cap.
    public init(softDailyLimit: Int) {
        self.softDailyLimit = max(1, softDailyLimit)
    }

    /// Default soft budgets aligned with documented free-tier limits.
    public static func defaultBudget(for provider: APIUsageProvider) -> APIUsageBudget {
        switch provider {
        case .orsRoute, .orsGeocode, .orsMatrix:
            APIUsageBudget(softDailyLimit: 2_000)
        case .tomTomFlow:
            APIUsageBudget(softDailyLimit: 2_500)
        case .overpass:
            APIUsageBudget(softDailyLimit: 10_000)
        case .openWeather:
            APIUsageBudget(softDailyLimit: 1_000)
        case .regCheck:
            APIUsageBudget(softDailyLimit: 50)
        case .dvla:
            APIUsageBudget(softDailyLimit: 100)
        }
    }
}

/// Rolled-up request counts for a single calendar day.
public struct APIUsageDaySummary: Sendable, Equatable {
    /// `yyyy-MM-dd` key in the current calendar.
    public let dayKey: String
    /// Per-provider counts for ``dayKey``.
    public var counts: [APIUsageProvider: Int]

    /// Total requests across all providers for the day.
    public var totalCount: Int {
        counts.values.reduce(0, +)
    }

    /// Creates a day summary.
    public init(dayKey: String, counts: [APIUsageProvider: Int] = [:]) {
        self.dayKey = dayKey
        self.counts = counts
    }

    /// Count for a single provider (zero when absent).
    public func count(for provider: APIUsageProvider) -> Int {
        counts[provider, default: 0]
    }

    /// Whether the provider is at or above its soft budget.
    public func isOverSoftBudget(for provider: APIUsageProvider) -> Bool {
        count(for: provider) >= APIUsageBudget.defaultBudget(for: provider).softDailyLimit
    }
}
