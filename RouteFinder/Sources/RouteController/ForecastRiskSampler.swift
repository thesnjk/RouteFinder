import Contracts
import DataLayer
import Foundation

/// Samples TomTom flow + OpenWeather forecast along the route for 1–3h horizon advisories.
public enum ForecastRiskSampler: Sendable {
    /// Arc-length offsets approximating ~1h / 2h / 3h at ~60 km/h HGV cruise (meters).
    public static let horizonOffsetsMeters: [Double] = [60_000, 120_000, 180_000]

    /// Minimum interval between forecast refreshes during navigation.
    public static let refreshIntervalSeconds: TimeInterval = 15 * 60

    /// Returns whether another forecast poll is allowed.
    public static func shouldRefresh(lastRefresh: Date?, now: Date = Date()) -> Bool {
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= refreshIntervalSeconds
    }

    /// Whether TomTom sampling should prefer the fleet proxy (parity with Android U14).
    public static func prefersFleetTomTom(
        fleetBaseURL: URL?,
        tomTomProxyConfigured: Bool
    ) -> Bool {
        fleetBaseURL != nil && tomTomProxyConfigured
    }

    /// Whether OpenWeather sampling should prefer the fleet proxy.
    public static func prefersFleetOpenWeather(
        fleetBaseURL: URL?,
        openWeatherProxyConfigured: Bool
    ) -> Bool {
        fleetBaseURL != nil && openWeatherProxyConfigured
    }

    /// Fleet TomTom flow URL: `{base}/v1/proxy/tomtom/flow?point=lat,lon`.
    public static func tomTomFlowProxyURL(
        fleetBaseURL: URL,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        var components = URLComponents(
            url: fleetBaseURL.appendingPathComponent("v1/proxy/tomtom/flow"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "point", value: "\(latitude),\(longitude)"),
        ]
        return components?.url
    }

    /// Fleet OpenWeather forecast URL: `{base}/v1/proxy/openweather/forecast?lat=&lon=&cnt=8`.
    public static func openWeatherForecastProxyURL(
        fleetBaseURL: URL,
        latitude: Double,
        longitude: Double,
        count: Int = 8
    ) -> URL? {
        var components = URLComponents(
            url: fleetBaseURL.appendingPathComponent("v1/proxy/openweather/forecast"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "cnt", value: String(count)),
        ]
        return components?.url
    }

    /// Builds advisories from TomTom flow at horizon sample points (no network — pure mapping).
    public static func trafficAdvisory(
        flow: TomTomFlowSegmentData,
        arcLengthMeters: Double,
        currentArcLengthMeters: Double
    ) -> RouteRiskAdvisory? {
        let remaining = max(0, arcLengthMeters - currentArcLengthMeters)
        guard remaining > 0 else { return nil }
        let ratio = flow.freeFlowSpeedKmh > 0
            ? flow.currentSpeedKmh / flow.freeFlowSpeedKmh
            : 1
        guard flow.roadClosed || ratio < 0.45 else { return nil }
        let hoursAhead = max(1, Int((remaining / 60_000).rounded()))
        let severity: RouteRiskSeverity = flow.roadClosed || ratio < 0.25 ? .severe : .caution
        let message: String
        if flow.roadClosed {
            message = "Forecast: closure risk ~\(hoursAhead)h ahead on route"
        } else {
            message = "Forecast: heavy traffic bottleneck ~\(hoursAhead)h ahead"
        }
        return RouteRiskAdvisory(
            id: "forecast-traffic-\(Int(arcLengthMeters))",
            kind: .traffic,
            severity: severity,
            distanceRemainingMeters: remaining,
            message: message,
            spokenPrompt: message,
            source: "forecastTomTom"
        )
    }

    /// Builds a weather advisory from hourly OpenWeather-style conditions.
    public static func weatherAdvisory(
        conditionMain: String,
        windGustMps: Double?,
        visibilityMeters: Double?,
        arcLengthMeters: Double,
        currentArcLengthMeters: Double
    ) -> RouteRiskAdvisory? {
        let remaining = max(0, arcLengthMeters - currentArcLengthMeters)
        guard remaining > 0 else { return nil }
        let main = conditionMain.lowercased()
        var parts: [String] = []
        var severity: RouteRiskSeverity = .info
        if main.contains("thunder") || main.contains("snow") || main.contains("ice") {
            parts.append(conditionMain)
            severity = .severe
        } else if main.contains("rain") || main.contains("drizzle") || main.contains("storm") {
            parts.append(conditionMain)
            severity = .caution
        }
        if let gust = windGustMps, gust >= 18 {
            parts.append(String(format: "gusts %.0f m/s", gust))
            severity = max(severity, .caution)
        }
        if let visibility = visibilityMeters, visibility > 0, visibility < 1_000 {
            parts.append("visibility under 1 km")
            severity = max(severity, .caution)
        }
        guard !parts.isEmpty else { return nil }
        let hoursAhead = max(1, Int((remaining / 60_000).rounded()))
        let message = "Forecast weather ~\(hoursAhead)h ahead: \(parts.joined(separator: ", "))"
        return RouteRiskAdvisory(
            id: "forecast-weather-\(Int(arcLengthMeters))-\(main.hashValue)",
            kind: .weather,
            severity: severity,
            distanceRemainingMeters: remaining,
            message: message,
            spokenPrompt: message,
            source: "forecastOpenWeather"
        )
    }

    /// Polls TomTom at horizon offsets and returns fused forecast traffic advisories.
    public static func sampleTomTomHorizon(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        trafficClient: TomTomTrafficFlowClient,
        offsetsMeters: [Double] = horizonOffsetsMeters
    ) async -> [RouteRiskAdvisory] {
        guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .tomTomFlow) else {
            return []
        }
        let points = LiveTrafficHazardSampler.samplePointsAhead(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            offsetsMeters: offsetsMeters
        )
        var items: [RouteRiskAdvisory] = []
        for point in points {
            let routingPoint = RoutingCoordinate(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
            do {
                let flow = try await trafficClient.fetchFlowSegment(at: routingPoint)
                if let advisory = trafficAdvisory(
                    flow: flow,
                    arcLengthMeters: point.arcLengthMeters,
                    currentArcLengthMeters: currentArcLengthMeters
                ) {
                    items.append(advisory)
                }
            } catch {
                continue
            }
        }
        return items
    }

    /// Polls TomTom via fleet `/v1/proxy/tomtom/flow` (operator-paid key).
    public static func sampleTomTomHorizonViaFleet(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        fleetBaseURL: URL,
        fleetAPIKey: String?,
        session: URLSession = .shared,
        offsetsMeters: [Double] = horizonOffsetsMeters
    ) async -> [RouteRiskAdvisory] {
        guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .tomTomFlow) else {
            return []
        }
        let points = LiveTrafficHazardSampler.samplePointsAhead(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            offsetsMeters: offsetsMeters
        )
        var items: [RouteRiskAdvisory] = []
        for point in points {
            guard let url = tomTomFlowProxyURL(
                fleetBaseURL: fleetBaseURL,
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            ) else { continue }
            do {
                let data = try await fleetGET(url: url, apiKey: fleetAPIKey, session: session)
                let flow = try TomTomTrafficFlowClient.parseFlowSegment(from: data)
                if let advisory = trafficAdvisory(
                    flow: flow,
                    arcLengthMeters: point.arcLengthMeters,
                    currentArcLengthMeters: currentArcLengthMeters
                ) {
                    items.append(advisory)
                }
            } catch {
                continue
            }
        }
        if !points.isEmpty {
            await APIUsageLedger.shared.record(provider: .tomTomFlow)
        }
        return items
    }

    /// Fetches OpenWeather 3-hour forecast slots and maps the nearest corridor sample.
    public static func sampleOpenWeatherHorizon(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        apiKey: String,
        session: URLSession = SecureURLSession.shared,
        offsetsMeters: [Double] = horizonOffsetsMeters
    ) async -> [RouteRiskAdvisory] {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let points = LiveTrafficHazardSampler.samplePointsAhead(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            offsetsMeters: offsetsMeters
        )
        guard let sample = points.first else { return [] }

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/forecast")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(sample.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(sample.coordinate.longitude)),
            URLQueryItem(name: "appid", value: trimmed),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "cnt", value: "8"),
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.applyAppIdentity()

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            await APIUsageLedger.shared.record(provider: .openWeather)
            return decodeOpenWeatherAdvisories(
                data: data,
                currentArcLengthMeters: currentArcLengthMeters,
                offsetsMeters: offsetsMeters
            )
        } catch {
            return []
        }
    }

    /// Fetches OpenWeather forecast via fleet `/v1/proxy/openweather/forecast`.
    public static func sampleOpenWeatherHorizonViaFleet(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        fleetBaseURL: URL,
        fleetAPIKey: String?,
        session: URLSession = .shared,
        offsetsMeters: [Double] = horizonOffsetsMeters
    ) async -> [RouteRiskAdvisory] {
        guard await APIUsageLedger.shared.allowsNonCriticalRequest(provider: .openWeather) else {
            return []
        }
        let points = LiveTrafficHazardSampler.samplePointsAhead(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            offsetsMeters: offsetsMeters
        )
        guard let sample = points.first,
              let url = openWeatherForecastProxyURL(
                fleetBaseURL: fleetBaseURL,
                latitude: sample.coordinate.latitude,
                longitude: sample.coordinate.longitude
              ) else {
            return []
        }
        do {
            let data = try await fleetGET(url: url, apiKey: fleetAPIKey, session: session)
            await APIUsageLedger.shared.record(provider: .openWeather)
            return decodeOpenWeatherAdvisories(
                data: data,
                currentArcLengthMeters: currentArcLengthMeters,
                offsetsMeters: offsetsMeters
            )
        } catch {
            return []
        }
    }

    /// Convenience: merges TomTom + OpenWeather horizon samples (device keys only).
    public static func sampleHorizon(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        tomTomAPIKey: String?,
        openWeatherAPIKey: String?
    ) async -> [RouteRiskAdvisory] {
        await sampleHorizon(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            tomTomAPIKey: tomTomAPIKey,
            openWeatherAPIKey: openWeatherAPIKey,
            fleetBaseURL: nil,
            fleetAPIKey: nil,
            tomTomProxyConfigured: false,
            openWeatherProxyConfigured: false
        )
    }

    /// Merges TomTom + OpenWeather horizon samples, preferring fleet proxy when configured (Android U14 parity).
    public static func sampleHorizon(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        tomTomAPIKey: String?,
        openWeatherAPIKey: String?,
        fleetBaseURL: URL?,
        fleetAPIKey: String?,
        tomTomProxyConfigured: Bool,
        openWeatherProxyConfigured: Bool
    ) async -> [RouteRiskAdvisory] {
        var items: [RouteRiskAdvisory] = []
        let useTomTomProxy = prefersFleetTomTom(
            fleetBaseURL: fleetBaseURL,
            tomTomProxyConfigured: tomTomProxyConfigured
        )
        let useOpenWeatherProxy = prefersFleetOpenWeather(
            fleetBaseURL: fleetBaseURL,
            openWeatherProxyConfigured: openWeatherProxyConfigured
        )
        let tomTom = tomTomAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if useTomTomProxy, let fleet = fleetBaseURL {
            items.append(contentsOf: await sampleTomTomHorizonViaFleet(
                route: route,
                currentArcLengthMeters: currentArcLengthMeters,
                fleetBaseURL: fleet,
                fleetAPIKey: fleetAPIKey
            ))
        } else if !tomTom.isEmpty, let client = try? TomTomTrafficFlowClient(apiKey: tomTom) {
            items.append(contentsOf: await sampleTomTomHorizon(
                route: route,
                currentArcLengthMeters: currentArcLengthMeters,
                trafficClient: client
            ))
        }

        let openWeather = openWeatherAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if useOpenWeatherProxy, let fleet = fleetBaseURL {
            items.append(contentsOf: await sampleOpenWeatherHorizonViaFleet(
                route: route,
                currentArcLengthMeters: currentArcLengthMeters,
                fleetBaseURL: fleet,
                fleetAPIKey: fleetAPIKey
            ))
        } else if !openWeather.isEmpty {
            items.append(contentsOf: await sampleOpenWeatherHorizon(
                route: route,
                currentArcLengthMeters: currentArcLengthMeters,
                apiKey: openWeather
            ))
        }
        return items
    }

    private static func decodeOpenWeatherAdvisories(
        data: Data,
        currentArcLengthMeters: Double,
        offsetsMeters: [Double]
    ) -> [RouteRiskAdvisory] {
        guard let decoded = try? JSONDecoder().decode(OpenWeatherForecastResponse.self, from: data) else {
            return []
        }
        var items: [RouteRiskAdvisory] = []
        for (index, entry) in decoded.list.prefix(3).enumerated() {
            let offsetIndex = min(index, offsetsMeters.count - 1)
            let arc = currentArcLengthMeters + offsetsMeters[offsetIndex]
            if let advisory = weatherAdvisory(
                conditionMain: entry.weather.first?.main ?? "",
                windGustMps: entry.wind?.gust,
                visibilityMeters: entry.visibility.map(Double.init),
                arcLengthMeters: arc,
                currentArcLengthMeters: currentArcLengthMeters
            ) {
                items.append(advisory)
            }
        }
        return items
    }

    private static func fleetGET(
        url: URL,
        apiKey: String?,
        session: URLSession
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyAppIdentity()
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private struct OpenWeatherForecastResponse: Decodable {
    let list: [OpenWeatherForecastEntry]
}

private struct OpenWeatherForecastEntry: Decodable {
    let weather: [OpenWeatherForecastCondition]
    let wind: OpenWeatherForecastWind?
    let visibility: Int?
}

private struct OpenWeatherForecastCondition: Decodable {
    let main: String
}

private struct OpenWeatherForecastWind: Decodable {
    let gust: Double?
}
