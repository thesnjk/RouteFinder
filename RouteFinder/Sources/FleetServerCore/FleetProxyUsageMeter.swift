import Foundation

/// Server-side soft/hard daily caps for operator-paid ORS proxy usage.
public struct FleetProxyUsageBudget: Sendable, Equatable {
    public var routeDailyCap: Int
    public var geocodeDailyCap: Int

    public static let `default` = FleetProxyUsageBudget(routeDailyCap: 2_000, geocodeDailyCap: 2_000)

    public init(routeDailyCap: Int, geocodeDailyCap: Int) {
        self.routeDailyCap = routeDailyCap
        self.geocodeDailyCap = geocodeDailyCap
    }
}

/// Calendar-day metering for fleet ORS proxy requests, optionally persisted to disk.
public actor FleetProxyUsageMeter {
    public enum Provider: String, Sendable {
        case orsRoute
        case orsGeocode
    }

    private struct Snapshot: Codable, Sendable {
        var dayStamp: String
        var routeCount: Int
        var geocodeCount: Int
    }

    private var dayStamp: String
    private var routeCount = 0
    private var geocodeCount = 0
    private let budget: FleetProxyUsageBudget
    private let calendar: Calendar
    private let persistenceURL: URL?

    /// Creates a meter. When `persistenceURL` is set, counts are loaded and saved atomically.
    public init(
        budget: FleetProxyUsageBudget = .default,
        calendar: Calendar = .current,
        persistenceURL: URL? = nil
    ) {
        self.budget = budget
        self.calendar = calendar
        self.persistenceURL = persistenceURL
        self.dayStamp = Self.dayKey(Date(), calendar: calendar)
        if let persistenceURL {
            Self.loadInto(
                url: persistenceURL,
                dayStamp: &dayStamp,
                routeCount: &routeCount,
                geocodeCount: &geocodeCount,
                calendar: calendar
            )
        }
    }

    /// Convenience: persist under `directory/proxy-meter.json`.
    public init(
        budget: FleetProxyUsageBudget = .default,
        storageDirectory: URL,
        calendar: Calendar = .current
    ) {
        let url = storageDirectory.appendingPathComponent("proxy-meter.json")
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        self.init(budget: budget, calendar: calendar, persistenceURL: url)
    }

    /// Returns false when the hard daily cap for this provider is already reached.
    public func allows(_ provider: Provider) -> Bool {
        rolloverIfNeeded()
        switch provider {
        case .orsRoute: return routeCount < budget.routeDailyCap
        case .orsGeocode: return geocodeCount < budget.geocodeDailyCap
        }
    }

    /// Records one successful (or attempted) upstream call.
    public func record(_ provider: Provider) {
        rolloverIfNeeded()
        switch provider {
        case .orsRoute: routeCount += 1
        case .orsGeocode: geocodeCount += 1
        }
        persistIfNeeded()
    }

    /// Snapshot for `/v1/proxy/status`.
    public func status(orsConfigured: Bool) -> FleetProxyStatusResponse {
        rolloverIfNeeded()
        return FleetProxyStatusResponse(
            orsConfigured: orsConfigured,
            routesToday: routeCount,
            routeDailyCap: budget.routeDailyCap,
            geocodeToday: geocodeCount,
            geocodeDailyCap: budget.geocodeDailyCap
        )
    }

    private func rolloverIfNeeded() {
        let today = Self.dayKey(Date(), calendar: calendar)
        guard today != dayStamp else { return }
        dayStamp = today
        routeCount = 0
        geocodeCount = 0
        persistIfNeeded()
    }

    private func persistIfNeeded() {
        guard let persistenceURL else { return }
        let snapshot = Snapshot(dayStamp: dayStamp, routeCount: routeCount, geocodeCount: geocodeCount)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // Metering must not take down the server; skip failed writes.
        }
    }

    private static func loadInto(
        url: URL,
        dayStamp: inout String,
        routeCount: inout Int,
        geocodeCount: inout Int,
        calendar: Calendar
    ) {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        let today = dayKey(Date(), calendar: calendar)
        if snapshot.dayStamp == today {
            dayStamp = snapshot.dayStamp
            routeCount = snapshot.routeCount
            geocodeCount = snapshot.geocodeCount
        } else {
            dayStamp = today
            routeCount = 0
            geocodeCount = 0
        }
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}

/// JSON body for fleet ORS proxy capability + metering.
public struct FleetProxyStatusResponse: Sendable, Codable, Equatable {
    public let orsConfigured: Bool
    public let routesToday: Int
    public let routeDailyCap: Int
    public let geocodeToday: Int
    public let geocodeDailyCap: Int

    public init(
        orsConfigured: Bool,
        routesToday: Int,
        routeDailyCap: Int,
        geocodeToday: Int,
        geocodeDailyCap: Int
    ) {
        self.orsConfigured = orsConfigured
        self.routesToday = routesToday
        self.routeDailyCap = routeDailyCap
        self.geocodeToday = geocodeToday
        self.geocodeDailyCap = geocodeDailyCap
    }
}
