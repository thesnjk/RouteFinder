import Foundation

/// Subset of `/v1/proxy/status` used by cab-phone forecast sampling (U14 parity).
public struct FleetForecastProxyCapabilities: Sendable, Codable, Equatable {
    /// True when the fleet server has a TomTom key for `/v1/proxy/tomtom/*`.
    public let tomTomConfigured: Bool
    /// True when the fleet server has an OpenWeather key for `/v1/proxy/openweather/*`.
    public let openWeatherConfigured: Bool

    /// Creates forecast proxy capability flags.
    public init(tomTomConfigured: Bool = false, openWeatherConfigured: Bool = false) {
        self.tomTomConfigured = tomTomConfigured
        self.openWeatherConfigured = openWeatherConfigured
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tomTomConfigured = try container.decodeIfPresent(Bool.self, forKey: .tomTomConfigured) ?? false
        openWeatherConfigured = try container.decodeIfPresent(Bool.self, forKey: .openWeatherConfigured) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case tomTomConfigured
        case openWeatherConfigured
    }
}
