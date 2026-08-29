import Contracts
import DataLayer
import Foundation

/// OpenWeather current-weather client backed by the shared TLS-only session.
public struct OpenWeatherClient: WeatherService, Sendable {
    public enum Error: Swift.Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case badStatus(Int)
        case emptyPayload

        public var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenWeather API key required. Set it in Settings or OPENWEATHER_API_KEY."
            case .invalidURL:
                return "OpenWeather request URL is invalid."
            case .badStatus(let code):
                return "OpenWeather returned HTTP \(code)."
            case .emptyPayload:
                return "OpenWeather returned an empty response."
            }
        }
    }

    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String? = nil, session: URLSession = SecureURLSession.shared) throws {
        let fromEnv = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fromStore = VehicleProfileStore.loadOpenWeatherAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = [apiKey, fromEnv, fromStore]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let resolved else {
            throw Error.missingAPIKey
        }
        self.apiKey = resolved
        self.session = session
    }

    public func fetchCurrent(at location: RoutingCoordinate) async throws -> WeatherCondition {
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(location.latitude)),
            URLQueryItem(name: "lon", value: String(location.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
        ]
        guard let url = components?.url else {
            throw Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Error.badStatus(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw Error.badStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw Error.emptyPayload
        }
        await APIUsageLedger.shared.record(provider: .openWeather)

        let payload = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        return WeatherConditionMapping.condition(
            description: payload.weather.first?.main,
            temperatureCelsius: payload.main.temp
        )
    }
}

private struct OpenWeatherResponse: Decodable {
    let weather: [OpenWeatherCondition]
    let main: OpenWeatherMain
}

private struct OpenWeatherCondition: Decodable {
    let main: String
}

private struct OpenWeatherMain: Decodable {
    let temp: Double
}
