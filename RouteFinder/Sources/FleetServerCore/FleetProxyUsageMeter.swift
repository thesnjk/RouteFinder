import Foundation

/// Server-side soft/hard daily caps for operator-paid proxy usage.
public struct FleetProxyUsageBudget: Sendable, Equatable {
    public var routeDailyCap: Int
    public var geocodeDailyCap: Int
    public var tomTomDailyCap: Int
    public var openWeatherDailyCap: Int
    public var overpassDailyCap: Int

    public static let `default` = FleetProxyUsageBudget(
        routeDailyCap: 2_000,
        geocodeDailyCap: 2_000,
        tomTomDailyCap: 500,
        openWeatherDailyCap: 200,
        overpassDailyCap: 100
    )

    public init(
        routeDailyCap: Int,
        geocodeDailyCap: Int,
        tomTomDailyCap: Int = 500,
        openWeatherDailyCap: Int = 200,
        overpassDailyCap: Int = 100
    ) {
        self.routeDailyCap = routeDailyCap
        self.geocodeDailyCap = geocodeDailyCap
        self.tomTomDailyCap = tomTomDailyCap
        self.openWeatherDailyCap = openWeatherDailyCap
        self.overpassDailyCap = overpassDailyCap
    }
}

/// Calendar-day metering for fleet ORS proxy requests, optionally persisted to disk.
public actor FleetProxyUsageMeter {
    public enum Provider: String, Sendable {
        case orsRoute
        case orsGeocode
        case tomTomFlow
        case openWeather
        case overpass
    }

    private struct Snapshot: Codable, Sendable {
        var dayStamp: String
        var routeCount: Int
        var geocodeCount: Int
        var tomTomCount: Int?
        var openWeatherCount: Int?
        var overpassCount: Int?
    }

    private var dayStamp: String
    private var routeCount = 0
    private var geocodeCount = 0
    private var tomTomCount = 0
    private var openWeatherCount = 0
    private var overpassCount = 0
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
                tomTomCount: &tomTomCount,
                openWeatherCount: &openWeatherCount,
                overpassCount: &overpassCount,
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
        case .tomTomFlow: return tomTomCount < budget.tomTomDailyCap
        case .openWeather: return openWeatherCount < budget.openWeatherDailyCap
        case .overpass: return overpassCount < budget.overpassDailyCap
        }
    }

    /// Records one successful (or attempted) upstream call.
    public func record(_ provider: Provider) {
        rolloverIfNeeded()
        switch provider {
        case .orsRoute: routeCount += 1
        case .orsGeocode: geocodeCount += 1
        case .tomTomFlow: tomTomCount += 1
        case .openWeather: openWeatherCount += 1
        case .overpass: overpassCount += 1
        }
        persistIfNeeded()
    }

    /// Snapshot for `/v1/proxy/status`.
    public func status(
        orsConfigured: Bool,
        tomTomConfigured: Bool = false,
        openWeatherConfigured: Bool = false
    ) -> FleetProxyStatusResponse {
        rolloverIfNeeded()
        return FleetProxyStatusResponse(
            orsConfigured: orsConfigured,
            routesToday: routeCount,
            routeDailyCap: budget.routeDailyCap,
            geocodeToday: geocodeCount,
            geocodeDailyCap: budget.geocodeDailyCap,
            tomTomConfigured: tomTomConfigured,
            openWeatherConfigured: openWeatherConfigured,
            overpassConfigured: true,
            tomTomToday: tomTomCount,
            tomTomDailyCap: budget.tomTomDailyCap,
            openWeatherToday: openWeatherCount,
            openWeatherDailyCap: budget.openWeatherDailyCap,
            overpassToday: overpassCount,
            overpassDailyCap: budget.overpassDailyCap
        )
    }

    private func rolloverIfNeeded() {
        let today = Self.dayKey(Date(), calendar: calendar)
        guard today != dayStamp else { return }
        dayStamp = today
        routeCount = 0
        geocodeCount = 0
        tomTomCount = 0
        openWeatherCount = 0
        overpassCount = 0
        persistIfNeeded()
    }

    private func persistIfNeeded() {
        guard let persistenceURL else { return }
        let snapshot = Snapshot(
            dayStamp: dayStamp,
            routeCount: routeCount,
            geocodeCount: geocodeCount,
            tomTomCount: tomTomCount,
            openWeatherCount: openWeatherCount,
            overpassCount: overpassCount
        )
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
        tomTomCount: inout Int,
        openWeatherCount: inout Int,
        overpassCount: inout Int,
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
            tomTomCount = snapshot.tomTomCount ?? 0
            openWeatherCount = snapshot.openWeatherCount ?? 0
            overpassCount = snapshot.overpassCount ?? 0
        } else {
            dayStamp = today
            routeCount = 0
            geocodeCount = 0
            tomTomCount = 0
            openWeatherCount = 0
            overpassCount = 0
        }
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }
}

/// JSON body for fleet ORS / forecast proxy capability + metering.
public struct FleetProxyStatusResponse: Sendable, Codable, Equatable {
    public let orsConfigured: Bool
    public let routesToday: Int
    public let routeDailyCap: Int
    public let geocodeToday: Int
    public let geocodeDailyCap: Int
    public let tomTomConfigured: Bool
    public let openWeatherConfigured: Bool
    public let overpassConfigured: Bool
    public let tomTomToday: Int
    public let tomTomDailyCap: Int
    public let openWeatherToday: Int
    public let openWeatherDailyCap: Int
    public let overpassToday: Int
    public let overpassDailyCap: Int

    public init(
        orsConfigured: Bool,
        routesToday: Int,
        routeDailyCap: Int,
        geocodeToday: Int,
        geocodeDailyCap: Int,
        tomTomConfigured: Bool = false,
        openWeatherConfigured: Bool = false,
        overpassConfigured: Bool = true,
        tomTomToday: Int = 0,
        tomTomDailyCap: Int = 500,
        openWeatherToday: Int = 0,
        openWeatherDailyCap: Int = 200,
        overpassToday: Int = 0,
        overpassDailyCap: Int = 100
    ) {
        self.orsConfigured = orsConfigured
        self.routesToday = routesToday
        self.routeDailyCap = routeDailyCap
        self.geocodeToday = geocodeToday
        self.geocodeDailyCap = geocodeDailyCap
        self.tomTomConfigured = tomTomConfigured
        self.openWeatherConfigured = openWeatherConfigured
        self.overpassConfigured = overpassConfigured
        self.tomTomToday = tomTomToday
        self.tomTomDailyCap = tomTomDailyCap
        self.openWeatherToday = openWeatherToday
        self.openWeatherDailyCap = openWeatherDailyCap
        self.overpassToday = overpassToday
        self.overpassDailyCap = overpassDailyCap
    }
}
