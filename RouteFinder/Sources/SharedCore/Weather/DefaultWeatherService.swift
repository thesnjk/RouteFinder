import DataLayer
import Foundation

extension Notification.Name {
    /// Posted when the OpenWeather API key is saved or cleared so live weather can hot-reload.
    public static let weatherConfigurationDidChange = Notification.Name(
        "RouteFinder.weatherConfigurationDidChange"
    )
}

/// Chooses the live weather backend for road-condition automation.
public enum WeatherBackendKind: String, Sendable, Equatable {
    /// OpenWeather HTTP API (works without WeatherKit entitlement).
    case openWeather
    /// Apple WeatherKit (requires paid-team entitlement at runtime; iOS only).
    case weatherKit
}

/// Factory for the default weather service used by `WeatherViewModel` on iOS.
public enum DefaultWeatherService {
    /// Selects OpenWeather when a usable API key is present; otherwise WeatherKit.
    ///
    /// Keys are resolved from the explicit argument, `OPENWEATHER_API_KEY`, or
    /// `VehicleProfileStore` (same order as `OpenWeatherClient`).
    public static func selectBackend(
        openWeatherAPIKey: String? = nil,
        environmentKey: String? = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"],
        storedKey: String? = VehicleProfileStore.loadOpenWeatherAPIKey()
    ) -> WeatherBackendKind {
        let candidates = [openWeatherAPIKey, environmentKey, storedKey]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return candidates.isEmpty ? .weatherKit : .openWeather
    }

    /// Settings hint shown when live weather fails without an OpenWeather key.
    public static let openWeatherSettingsHint =
        "Add an OpenWeather API key in Settings for live auto weather without WeatherKit."

    /// Posts `weatherConfigurationDidChange` after OpenWeather credentials change.
    public static func notifyConfigurationDidChange() {
        NotificationCenter.default.post(name: .weatherConfigurationDidChange, object: nil)
    }

    #if os(iOS)
    /// Builds the preferred weather service for automatic road-condition updates.
    public static func make(
        openWeatherAPIKey: String? = nil
    ) -> any WeatherService {
        switch selectBackend(openWeatherAPIKey: openWeatherAPIKey) {
        case .openWeather:
            if let client = try? OpenWeatherClient(apiKey: openWeatherAPIKey) {
                return client
            }
            return WeatherKitWeatherService()
        case .weatherKit:
            return WeatherKitWeatherService()
        }
    }
    #endif
}
