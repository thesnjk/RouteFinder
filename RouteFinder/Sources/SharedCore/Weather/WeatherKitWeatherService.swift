#if os(iOS)
import Contracts
import CoreLocation
import Foundation
import WeatherKit

/// WeatherKit-backed live weather provider for iOS road-condition automation.
public struct WeatherKitWeatherService: WeatherService, Sendable {
    private let service: WeatherKit.WeatherService

    /// Creates a WeatherKit weather service.
    public init(service: WeatherKit.WeatherService = .shared) {
        self.service = service
    }

    public func fetchCurrent(at location: RoutingCoordinate) async throws -> WeatherCondition {
        let coordinate = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let weather = try await service.weather(for: coordinate)
        let current = weather.currentWeather
        let description = current.condition.description
        let temperatureCelsius = current.temperature.converted(to: .celsius).value
        return WeatherConditionMapping.condition(
            description: description,
            temperatureCelsius: temperatureCelsius
        )
    }
}
#endif
