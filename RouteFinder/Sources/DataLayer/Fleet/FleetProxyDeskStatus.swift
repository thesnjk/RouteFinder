import Foundation

/// Desk-facing decode of `GET /v1/proxy/status` (ORS + forecast metering).
///
/// Lives in DataLayer so Mac Dispatch can show fair-use burn without importing FleetServerCore.
public struct FleetProxyDeskStatus: Sendable, Codable, Equatable {
    /// True when the fleet server was started with an ORS key.
    public let orsConfigured: Bool
    /// Routes counted against the daily ORS route cap today.
    public let routesToday: Int
    /// Daily ORS route budget.
    public let routeDailyCap: Int
    /// Geocodes counted against the daily ORS geocode cap today.
    public let geocodeToday: Int
    /// Daily ORS geocode budget.
    public let geocodeDailyCap: Int
    /// True when TomTom flow proxy is configured.
    public let tomTomConfigured: Bool
    /// True when OpenWeather forecast proxy is configured.
    public let openWeatherConfigured: Bool
    /// TomTom requests counted today (when configured).
    public let tomTomToday: Int
    /// Daily TomTom budget.
    public let tomTomDailyCap: Int
    /// OpenWeather requests counted today (when configured).
    public let openWeatherToday: Int
    /// Daily OpenWeather budget.
    public let openWeatherDailyCap: Int

    /// Fraction of cap at which the desk shows a near-cap warning.
    public static let nearCapFraction: Double = 0.9

    /// Creates a desk proxy status snapshot.
    public init(
        orsConfigured: Bool,
        routesToday: Int,
        routeDailyCap: Int,
        geocodeToday: Int,
        geocodeDailyCap: Int,
        tomTomConfigured: Bool = false,
        openWeatherConfigured: Bool = false,
        tomTomToday: Int = 0,
        tomTomDailyCap: Int = 500,
        openWeatherToday: Int = 0,
        openWeatherDailyCap: Int = 200
    ) {
        self.orsConfigured = orsConfigured
        self.routesToday = routesToday
        self.routeDailyCap = routeDailyCap
        self.geocodeToday = geocodeToday
        self.geocodeDailyCap = geocodeDailyCap
        self.tomTomConfigured = tomTomConfigured
        self.openWeatherConfigured = openWeatherConfigured
        self.tomTomToday = tomTomToday
        self.tomTomDailyCap = tomTomDailyCap
        self.openWeatherToday = openWeatherToday
        self.openWeatherDailyCap = openWeatherDailyCap
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orsConfigured = try container.decodeIfPresent(Bool.self, forKey: .orsConfigured) ?? false
        routesToday = try container.decodeIfPresent(Int.self, forKey: .routesToday) ?? 0
        routeDailyCap = try container.decodeIfPresent(Int.self, forKey: .routeDailyCap) ?? 0
        geocodeToday = try container.decodeIfPresent(Int.self, forKey: .geocodeToday) ?? 0
        geocodeDailyCap = try container.decodeIfPresent(Int.self, forKey: .geocodeDailyCap) ?? 0
        tomTomConfigured = try container.decodeIfPresent(Bool.self, forKey: .tomTomConfigured) ?? false
        openWeatherConfigured = try container.decodeIfPresent(Bool.self, forKey: .openWeatherConfigured) ?? false
        tomTomToday = try container.decodeIfPresent(Int.self, forKey: .tomTomToday) ?? 0
        tomTomDailyCap = try container.decodeIfPresent(Int.self, forKey: .tomTomDailyCap) ?? 500
        openWeatherToday = try container.decodeIfPresent(Int.self, forKey: .openWeatherToday) ?? 0
        openWeatherDailyCap = try container.decodeIfPresent(Int.self, forKey: .openWeatherDailyCap) ?? 200
    }

    /// Remaining ORS route budget for today (never negative).
    public var routesRemaining: Int {
        max(0, routeDailyCap - routesToday)
    }

    /// Remaining ORS geocode budget for today (never negative).
    public var geocodesRemaining: Int {
        max(0, geocodeDailyCap - geocodeToday)
    }

    /// True when routes used ≥ 90% of the daily cap (and cap > 0).
    public var isNearRouteCap: Bool {
        isNearCap(used: routesToday, cap: routeDailyCap)
    }

    /// True when geocodes used ≥ 90% of the daily cap (and cap > 0).
    public var isNearGeocodeCap: Bool {
        isNearCap(used: geocodeToday, cap: geocodeDailyCap)
    }

    /// True when either ORS meter is near its daily cap.
    public var isNearAnyORSCap: Bool {
        orsConfigured && (isNearRouteCap || isNearGeocodeCap)
    }

    /// Primary ORS metering line for the desk card.
    public var orsSummaryLine: String {
        guard orsConfigured else {
            return "ORS proxy: off (start server with --ors-key for address search and driver routing)"
        }
        return "ORS proxy: on · \(routesToday)/\(routeDailyCap) routes · \(routesRemaining) left · \(geocodeToday)/\(geocodeDailyCap) geocodes · \(geocodesRemaining) left"
    }

    /// Forecast proxy line (TomTom + OpenWeather).
    public var forecastSummaryLine: String {
        let tomTom: String
        if tomTomConfigured {
            tomTom = "TomTom: on · \(tomTomToday)/\(tomTomDailyCap) today"
        } else {
            tomTom = "TomTom: off"
        }
        let weather: String
        if openWeatherConfigured {
            weather = "OpenWeather: on · \(openWeatherToday)/\(openWeatherDailyCap) today"
        } else {
            weather = "OpenWeather: off"
        }
        return "\(tomTom) · \(weather)"
    }

    /// Ordered summary lines for the Mac Dispatch proxy card.
    public var summaryLines: [String] {
        [orsSummaryLine, forecastSummaryLine]
    }

    /// Near-cap caption when either ORS meter is ≥ 90% used.
    public var nearCapWarning: String? {
        guard isNearAnyORSCap else { return nil }
        return "Near daily proxy cap — raise --route-daily-cap / --geocode-daily-cap or wait until tomorrow."
    }

    private func isNearCap(used: Int, cap: Int) -> Bool {
        guard cap > 0 else { return false }
        return Double(used) >= Double(cap) * Self.nearCapFraction
    }

    private enum CodingKeys: String, CodingKey {
        case orsConfigured
        case routesToday
        case routeDailyCap
        case geocodeToday
        case geocodeDailyCap
        case tomTomConfigured
        case openWeatherConfigured
        case tomTomToday
        case tomTomDailyCap
        case openWeatherToday
        case openWeatherDailyCap
    }
}
