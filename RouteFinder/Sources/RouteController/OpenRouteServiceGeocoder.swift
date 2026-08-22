import Contracts
import DataLayer
import Foundation

/// Errors from the HeiGIT OpenRouteService geocoding client.
public enum OpenRouteServiceGeocoderError: Error, Sendable, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case unauthorized(status: Int)
    case rateLimited(status: Int)
    case decodingFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "HeiGIT API key is required. Add your key in Settings."
        case .invalidResponse:
            return "Geocoding service returned an unexpected response."
        case .unauthorized(let status):
            return "Geocoding service rejected the request (HTTP \(status)). Check your HeiGIT API key."
        case .rateLimited(let status):
            return "Geocoding rate limit exceeded (HTTP \(status)). Please wait a moment and try again."
        case .decodingFailed(let underlying):
            return DecodingDiagnostics.userMessage(for: underlying)
        }
    }
}

/// Geocoder using HeiGIT OpenRouteService Pelias search (`GET /pelias/v1/search`).
///
/// Suggestion labels are for UI display only. Routing consumers must use
/// ``GeocodeSuggestion/routingCoordinate`` or ``GeocodeSuggestion/coordinate``.
public actor OpenRouteServiceGeocoder {
    private let session: URLSession
    private let baseURL: URL
    private let cache: GeocoderCache
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.25

    /// Creates an OpenRouteService geocoder with optional cache.
    public init(
        baseURL: URL = URL(string: ORSAPIDefaults.peliasBaseURL)!,
        session: URLSession = SecureURLSession.shared,
        cache: GeocoderCache = GeocoderCache()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cache = cache
    }

    /// Searches for places near the given coordinate (viewport-biased typeahead).
    public func searchBiased(
        query: String,
        near coordinate: Coordinate,
        apiKey: String,
        limit: Int = 8
    ) async throws -> [GeocodeSuggestion] {
        try await performSearch(
            query: query,
            apiKey: apiKey,
            cacheKey: GeocoderCache.cacheKey(query: query, near: coordinate),
            queryItems: biasedQueryItems(query: query, near: coordinate, limit: limit)
        )
    }

    /// Searches globally without a viewport bias.
    public func searchGlobal(
        query: String,
        near coordinate: Coordinate,
        apiKey: String,
        limit: Int = 8
    ) async throws -> [GeocodeSuggestion] {
        try await performSearch(
            query: query,
            apiKey: apiKey,
            cacheKey: GeocoderCache.cacheKeyGlobal(query: query, near: coordinate),
            queryItems: globalQueryItems(query: query, near: coordinate, limit: limit)
        )
    }

    /// Searches for places near the given coordinate (viewport-biased).
    public func search(
        query: String,
        near coordinate: Coordinate,
        apiKey: String,
        limit: Int = 8
    ) async throws -> [GeocodeSuggestion] {
        try await searchBiased(query: query, near: coordinate, apiKey: apiKey, limit: limit)
    }

    private func performSearch(
        query: String,
        apiKey: String,
        cacheKey: String,
        queryItems: [URLQueryItem]
    ) async throws -> [GeocodeSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw OpenRouteServiceGeocoderError.missingAPIKey
        }

        if let cached = await cache.suggestions(forKey: cacheKey) {
            return cached
        }

        try await throttle()

        var components = URLComponents(
            url: baseURL.appendingPathComponent(ORSAPIDefaults.geocodeSearchPath),
            resolvingAgainstBaseURL: false
        )!
        var items = queryItems
        items.append(URLQueryItem(name: "api_key", value: key))
        components.queryItems = items

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.applyAppIdentity()

        let (data, response) = try await session.data(for: request)
        logGeocodeResponse(request: request, response: response, data: data)
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouteServiceGeocoderError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw OpenRouteServiceGeocoderError.unauthorized(status: http.statusCode)
        }
        if http.statusCode == 429 {
            throw OpenRouteServiceGeocoderError.rateLimited(status: http.statusCode)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenRouteServiceGeocoderError.invalidResponse
        }

        let collection: ORSGeocodeFeatureCollection
        do {
            collection = try JSONDecoder().decode(ORSGeocodeFeatureCollection.self, from: data)
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "ORS geocode search decode",
                responsePreview: DecodingDiagnostics.preview(of: data)
            )
            throw OpenRouteServiceGeocoderError.decodingFailed(underlying: error)
        }

        let suggestions = collection.features.compactMap { Self.suggestion(from: $0) }
        await cache.store(suggestions, forKey: cacheKey)
        return suggestions
    }

    /// Formats an ORS Pelias feature into a geocode suggestion.
    public static func suggestion(from feature: ORSGeocodeFeature) -> GeocodeSuggestion? {
        guard feature.geometry.type == "Point",
              feature.geometry.coordinates.count >= 2 else { return nil }

        let lon = feature.geometry.coordinates[0]
        let lat = feature.geometry.coordinates[1]
        let properties = feature.properties
        let label = properties.label ?? properties.name ?? "Unknown place"
        let title = properties.name ?? label.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? label
        let stableID = properties.id ?? feature.id ?? UUID().uuidString

        return GeocodeSuggestion(
            id: "ors:\(stableID)",
            title: title,
            subtitle: label,
            coordinate: Coordinate(latitude: lat, longitude: lon),
            isLocal: false
        )
    }

    private func biasedQueryItems(query: String, near coordinate: Coordinate, limit: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "text", value: query.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "size", value: String(limit)),
            URLQueryItem(name: "focus.point.lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "focus.point.lon", value: String(coordinate.longitude)),
        ]
        items.append(contentsOf: ukBoundaryQueryItems())
        return items
    }

    private func globalQueryItems(query: String, near coordinate: Coordinate, limit: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "text", value: query.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "size", value: String(limit)),
            URLQueryItem(name: "focus.point.lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "focus.point.lon", value: String(coordinate.longitude)),
        ]
        items.append(contentsOf: ukBoundaryQueryItems())
        return items
    }

    private func ukBoundaryQueryItems() -> [URLQueryItem] {
        [URLQueryItem(name: "boundary.country", value: "GBR")]
    }

    private func throttle() async throws {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try await Task.sleep(for: .milliseconds(Int((minInterval - elapsed) * 1000)))
        }
        lastRequestTime = Date()
    }

    private func logGeocodeResponse(request: URLRequest, response: URLResponse, data: Data) {
        let urlString = request.url?.absoluteString ?? "<nil>"
        let redactedURL = urlString.replacingOccurrences(
            of: #"api_key=[^&]+"#,
            with: "api_key=***",
            options: .regularExpression
        )
        print("[Geocode Debug] Targeting URL: \(redactedURL)")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("[Geocode Debug] Request Headers: \(headers)")
        } else {
            print("[Geocode Debug] Request Headers: <none>")
        }

        if let http = response as? HTTPURLResponse {
            print("[Geocode Debug] Status Code: \(http.statusCode)")
            if !(200..<300).contains(http.statusCode) {
                print("[Geocode Debug] Response Body: \(DecodingDiagnostics.preview(of: data))")
            }
        } else {
            print("[Geocode Debug] Status Code: <non-HTTP response>")
            print("[Geocode Debug] Response Body: \(DecodingDiagnostics.preview(of: data))")
        }
    }
}

// MARK: - ORS Pelias GeoJSON types

/// Pelias geocode feature collection returned by ORS.
public struct ORSGeocodeFeatureCollection: Decodable, Sendable {
    public let features: [ORSGeocodeFeature]
}

/// Single Pelias geocode feature.
public struct ORSGeocodeFeature: Decodable, Sendable {
    public let id: String?
    public let geometry: ORSGeocodeGeometry
    public let properties: ORSGeocodeProperties
}

/// Point geometry with `[lon, lat]` coordinates.
public struct ORSGeocodeGeometry: Decodable, Sendable {
    public let type: String
    public let coordinates: [Double]
}

/// Pelias feature properties used for suggestion labels.
public struct ORSGeocodeProperties: Decodable, Sendable {
    public let id: String?
    public let label: String?
    public let name: String?
}
