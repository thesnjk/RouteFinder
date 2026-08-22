import Contracts
import Foundation

/// Surface weather classification for routing friction and lookahead scaling.
public enum WeatherCondition: String, Sendable, Codable, CaseIterable {
    case dry
    case rain
    case ice

    /// Maps to the shared friction model used by CostModel and simulation.
    public var environmentalContext: EnvironmentalContext {
        switch self {
        case .dry: return .dry
        case .rain: return .rain
        case .ice: return .ice
        }
    }

    /// Parses CLI override text (`dry`, `rain`, `ice`).
    public init?(cliText: String) {
        self.init(rawValue: cliText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// Fetches live weather for a coordinate.
public protocol WeatherService: Sendable {
    func fetchCurrent(at location: RoutingCoordinate) async throws -> WeatherCondition
}

/// Routing request enriched with resolved weather for downstream engines.
public struct WeatherAwareRoutingRequest: Sendable {
    public let weather: WeatherCondition
    public let environmentalContext: EnvironmentalContext
    public let startLocation: RoutingCoordinate?

    public init(weather: WeatherCondition, startLocation: RoutingCoordinate?) {
        self.weather = weather
        self.environmentalContext = weather.environmentalContext
        self.startLocation = startLocation
    }
}

public enum WeatherResolver {
    /// Uses CLI override when present; otherwise fetches at `startLocation` or defaults to dry.
    public static func resolve(
        override: WeatherCondition?,
        startLocation: RoutingCoordinate?,
        service: any WeatherService
    ) async throws -> WeatherCondition {
        if let override {
            return override
        }
        guard let startLocation else {
            return .dry
        }
        return try await service.fetchCurrent(at: startLocation)
    }

    public static func makeRequest(
        override: WeatherCondition?,
        startLocation: RoutingCoordinate?,
        service: any WeatherService
    ) async throws -> WeatherAwareRoutingRequest {
        let weather = try await resolve(
            override: override,
            startLocation: startLocation,
            service: service
        )
        return WeatherAwareRoutingRequest(weather: weather, startLocation: startLocation)
    }
}
