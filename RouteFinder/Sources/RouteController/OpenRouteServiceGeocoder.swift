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
    private let hitCache: DiskGeocodeCache
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.25

    /// Creates an OpenRouteService geocoder with optional cache.
    public init(
        baseURL: URL = URL(string: ORSAPIDefaults.peliasBaseURL)!,
        session: URLSession = SecureURLSession.shared,
        cache: GeocoderCache = GeocoderCache(),
        hitCache: DiskGeocodeCache = DiskGeocodeCache()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cache = cache
        self.hitCache = hitCache
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
            queryItems: Self.biasedQueryItems(query: query, near: coordinate, limit: limit)
        )
    }

    /// Searches globally without a country boundary lock (focus still ranks near the map).
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
            queryItems: Self.globalQueryItems(query: query, near: coordinate, limit: limit)
        )
    }

    /// Searches globally without an explicit focus coordinate (neutral focus).
    public func searchGlobal(
        query: String,
        apiKey: String,
        limit: Int = 8
    ) async throws -> [GeocodeSuggestion] {
        try await searchGlobal(
            query: query,
            near: Coordinate(latitude: 0, longitude: 0),
            apiKey: apiKey,
            limit: limit
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

    /// Returns whether a free-text query likely refers to a place outside the United Kingdom.
    ///
    /// Used to prefer global Pelias search over UK-biased results for overseas destinations.
    public static func querySuggestsOutsideUnitedKingdom(_ query: String) -> Bool {
        let lowered = query.lowercased()
        let overseasMarkers = [
            "france", "paris", "germany", "berlin", "spain", "madrid", "italy", "rome",
            "ireland", "dublin", "netherlands", "amsterdam", "belgium", "brussels",
            "portugal", "lisbon", "poland", "warsaw", "usa", "united states", "new york",
            "canada", "toronto", "australia", "sydney", "europe", "eu ",
            "norway", "oslo", "ålesund", "alesund", "sweden", "stockholm", "denmark", "copenhagen",
        ]
        if overseasMarkers.contains(where: { lowered.contains($0) }) {
            return true
        }
        // Nordic / Euro street suffixes (incl. common typos like "wegen").
        let streetMarkers = [
            "vegen", "wegen", "veg", "vei", "väg", "gate", "gata",
            "strasse", "straße", "allee", "platz", " rue ", " via ",
        ]
        if streetMarkers.contains(where: { lowered.contains($0) }) {
            return true
        }
        // Leading "rue "/"via " when query starts with the marker.
        if lowered.hasPrefix("rue ") || lowered.hasPrefix("via ") {
            return true
        }
        // Continental-style postcodes (digits-first) often indicate non-UK addresses.
        let compact = lowered.filter { !$0.isWhitespace }
        if compact.range(of: #"^\d{4,5}"#, options: .regularExpression) != nil {
            return true
        }
        return false
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
        await hitCache.store(query: trimmed, suggestions: suggestions)
        return suggestions
    }

    /// Returns last-N disk-cached Pelias hits for offline / no-key fallback.
    public func cachedHits(matching query: String) async -> [GeocodeSuggestion] {
        if let exact = await hitCache.suggestions(matching: query) {
            return exact
        }
        return await hitCache.suggestions(prefix: query)
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

    /// Builds UK-biased Pelias query items (`boundary.country=GBR`). Exposed for tests.
    public static func biasedQueryItems(query: String, near coordinate: Coordinate, limit: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "text", value: query.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "size", value: String(limit)),
            URLQueryItem(name: "focus.point.lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "focus.point.lon", value: String(coordinate.longitude)),
        ]
        items.append(contentsOf: ukBoundaryQueryItems())
        return items
    }

    /// Builds global Pelias query items (no country lock, no map focus). Exposed for tests.
    ///
    /// Omitting ``focus.point`` prevents UK-map bias from ranking domestic “33 …” hits
    /// ahead of overseas matches.
    public static func globalQueryItems(query: String, near coordinate: Coordinate, limit: Int) -> [URLQueryItem] {
        _ = coordinate
        return [
            URLQueryItem(name: "text", value: query.trimmingCharacters(in: .whitespaces)),
            URLQueryItem(name: "size", value: String(limit)),
        ]
    }

    private static func ukBoundaryQueryItems() -> [URLQueryItem] {
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
