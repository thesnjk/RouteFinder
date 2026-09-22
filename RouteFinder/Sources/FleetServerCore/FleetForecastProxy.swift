import Foundation
import Hummingbird
import NIOCore

/// Proxies TomTom flow, OpenWeather forecast, and Overpass clearance using operator-held keys.
/// Overpass needs no key; TomTom / OpenWeather register only when keys are configured.
public enum FleetForecastProxy {
    public static let tomTomFlowUpstream =
        "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json"
    public static let openWeatherForecastUpstream =
        "https://api.openweathermap.org/data/2.5/forecast"
    public static let overpassUpstream = "https://overpass-api.de/api/interpreter"

    /// Registers `/v1/proxy/tomtom/*`, `/v1/proxy/openweather/*`, `/v1/proxy/overpass/*`.
    public static func registerRoutes(
        on router: Router<BasicRequestContext>,
        tomTomAPIKey: String?,
        openWeatherAPIKey: String?,
        meter: FleetProxyUsageMeter,
        session: URLSession = .shared
    ) {
        let tomTom = tomTomAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let openWeather = openWeatherAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !tomTom.isEmpty {
            router.get("v1/proxy/tomtom/flow") { request, _ async throws -> Response in
                guard await meter.allows(.tomTomFlow) else {
                    throw HTTPError(.tooManyRequests, message: "Fleet TomTom flow daily cap reached.")
                }
                guard let point = queryValue(request, name: "point"), !point.isEmpty else {
                    throw HTTPError(.badRequest, message: "Missing point=lat,lon query.")
                }
                guard var components = URLComponents(string: tomTomFlowUpstream) else {
                    throw HTTPError(.badGateway, message: "Invalid TomTom upstream.")
                }
                components.queryItems = [
                    URLQueryItem(name: "point", value: point),
                    URLQueryItem(name: "unit", value: "KMPH"),
                    URLQueryItem(name: "key", value: tomTom),
                ]
                guard let url = components.url else {
                    throw HTTPError(.badRequest, message: "Invalid TomTom query.")
                }
                var upstream = URLRequest(url: url)
                upstream.httpMethod = "GET"
                upstream.setValue("application/json", forHTTPHeaderField: "Accept")
                upstream.setValue("RouteFinderFleetServer/1.0", forHTTPHeaderField: "User-Agent")
                await meter.record(.tomTomFlow)
                return try await forward(upstream, session: session)
            }
        }

        if !openWeather.isEmpty {
            router.get("v1/proxy/openweather/forecast") { request, _ async throws -> Response in
                guard await meter.allows(.openWeather) else {
                    throw HTTPError(.tooManyRequests, message: "Fleet OpenWeather daily cap reached.")
                }
                guard let lat = queryValue(request, name: "lat"),
                      let lon = queryValue(request, name: "lon") else {
                    throw HTTPError(.badRequest, message: "Missing lat/lon query.")
                }
                guard var components = URLComponents(string: openWeatherForecastUpstream) else {
                    throw HTTPError(.badGateway, message: "Invalid OpenWeather upstream.")
                }
                components.queryItems = [
                    URLQueryItem(name: "lat", value: lat),
                    URLQueryItem(name: "lon", value: lon),
                    URLQueryItem(name: "appid", value: openWeather),
                    URLQueryItem(name: "units", value: "metric"),
                    URLQueryItem(name: "cnt", value: queryValue(request, name: "cnt") ?? "8"),
                ]
                guard let url = components.url else {
                    throw HTTPError(.badRequest, message: "Invalid OpenWeather query.")
                }
                var upstream = URLRequest(url: url)
                upstream.httpMethod = "GET"
                upstream.setValue("application/json", forHTTPHeaderField: "Accept")
                upstream.setValue("RouteFinderFleetServer/1.0", forHTTPHeaderField: "User-Agent")
                await meter.record(.openWeather)
                return try await forward(upstream, session: session)
            }
        }

        // Overpass is always available (no operator key).
        router.post("v1/proxy/overpass/interpreter") { request, _ async throws -> Response in
            guard await meter.allows(.overpass) else {
                throw HTTPError(.tooManyRequests, message: "Fleet Overpass daily cap reached.")
            }
            guard let url = URL(string: overpassUpstream) else {
                throw HTTPError(.badGateway, message: "Invalid Overpass upstream.")
            }
            var upstream = URLRequest(url: url)
            upstream.httpMethod = "POST"
            upstream.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            upstream.setValue("application/json", forHTTPHeaderField: "Accept")
            upstream.setValue("RouteFinderFleetServer/1.0", forHTTPHeaderField: "User-Agent")
            upstream.httpBody = try await collectBodyData(request)
            await meter.record(.overpass)
            return try await forward(upstream, session: session)
        }
    }

    private static func queryValue(_ request: Request, name: String) -> String? {
        guard let query = request.uri.query else { return nil }
        let pairs = query.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, parts[0] == name else { continue }
            return String(parts[1]).removingPercentEncoding ?? String(parts[1])
        }
        return nil
    }

    private static func collectBodyData(_ request: Request) async throws -> Data {
        var buffer = ByteBuffer()
        for try await chunk in request.body {
            var mutable = chunk
            buffer.writeBuffer(&mutable)
        }
        return Data(buffer.readableBytesView)
    }

    private static func forward(_ request: URLRequest, session: URLSession) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError(.badGateway, message: "Upstream returned a non-HTTP response.")
        }
        var buffer = ByteBuffer()
        buffer.writeBytes(data)
        var headers = HTTPFields()
        if let contentType = http.value(forHTTPHeaderField: "Content-Type") {
            headers[.contentType] = contentType
        } else {
            headers[.contentType] = "application/json; charset=utf-8"
        }
        let status = HTTPResponse.Status(code: http.statusCode)
        return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
    }
}
