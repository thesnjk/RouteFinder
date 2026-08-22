import Contracts
import DataLayer
import Foundation
import Testing
@testable import RouteController

@Suite("OpenRouteServiceGeocoder", .serialized)
struct OpenRouteServiceGeocoderTests {
    private let sampleResponse = """
    {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": { "type": "Point", "coordinates": [1.30, 52.63] },
        "properties": {
          "id": "place:1",
          "label": "Norwich, Norfolk, England",
          "name": "Norwich"
        }
      }]
    }
    """.data(using: .utf8)!

    @Test("search sends app User-Agent header")
    func userAgentHeader() async throws {
        let captured = CapturedRequestBox()
        let query = "user-agent-\(UUID().uuidString)"
        let client = try makeClient(captured: captured) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, self.sampleResponse)
        }

        _ = try await client.searchGlobal(query: query, apiKey: "test-key")

        let userAgent = captured.request?.value(forHTTPHeaderField: "User-Agent")
        #expect(userAgent == NetworkClientIdentity.userAgent)
    }

    @Test("search targets Pelias v1 endpoint")
    func peliasEndpointURL() async throws {
        let captured = CapturedRequestBox()
        let query = "pelias-\(UUID().uuidString)"
        let client = try makeClient(captured: captured) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"features\":[]}".utf8))
        }

        _ = try await client.searchGlobal(query: query, apiKey: "test-key")

        let urlString = try #require(captured.request?.url?.absoluteString)
        #expect(urlString.hasPrefix("https://api.heigit.org/pelias/v1/search"))
    }

    @Test("search includes api_key query parameter")
    func apiKeyQueryParam() async throws {
        let captured = CapturedRequestBox()
        let query = "norwich-\(UUID().uuidString)"
        let client = try makeClient(captured: captured) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"features\":[]}".utf8))
        }

        _ = try await client.searchGlobal(query: query, apiKey: "secret-key-123")

        let urlString = try #require(captured.request?.url?.absoluteString)
        #expect(urlString.contains("api_key="))
        #expect(urlString.contains("secret-key-123") || urlString.contains("secret-key-123".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
    }

    @Test("parses features into GeocodeSuggestion")
    func parsesFeatures() async throws {
        let query = "norwich-\(UUID().uuidString)"
        let client = try makeClient { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, self.sampleResponse)
        }

        let results = try await client.searchGlobal(query: query, apiKey: "test-key")
        #expect(results.count == 1)
        #expect(results[0].id == "ors:place:1")
        #expect(results[0].title == "Norwich")
        #expect(results[0].coordinate.latitude == 52.63)
        #expect(results[0].coordinate.longitude == 1.30)
    }

    @Test("HTTP 401 maps to unauthorized error")
    func unauthorizedError() async throws {
        let query = "unauthorized-\(UUID().uuidString)"
        let client = try makeClient { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await client.searchGlobal(query: query, apiKey: "bad-key")
            Issue.record("Expected unauthorized error")
        } catch let error as OpenRouteServiceGeocoderError {
            if case .unauthorized(let status) = error {
                #expect(status == 401)
            } else {
                Issue.record("Expected unauthorized, got \(error)")
            }
        }
    }

    @Test("HTTP 429 maps to rateLimited error")
    func rateLimitedError() async throws {
        let query = "rate-limit-\(UUID().uuidString)"
        let client = try makeClient { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await client.searchGlobal(query: query, apiKey: "test-key")
            Issue.record("Expected rateLimited error")
        } catch let error as OpenRouteServiceGeocoderError {
            if case .rateLimited(let status) = error {
                #expect(status == 429)
            } else {
                Issue.record("Expected rateLimited, got \(error)")
            }
        }
    }

    @Test("empty API key throws missingAPIKey")
    func missingAPIKey() async throws {
        let client = try makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.searchGlobal(query: "Norwich", apiKey: "")
            Issue.record("Expected missingAPIKey")
        } catch let error as OpenRouteServiceGeocoderError {
            if case .missingAPIKey = error {
                #expect(Bool(true))
            } else {
                Issue.record("Expected missingAPIKey, got \(error)")
            }
        }
    }
}

// MARK: - Mock URL session

private final class CapturedRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeClient(
    captured: CapturedRequestBox = CapturedRequestBox(),
    handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
) throws -> OpenRouteServiceGeocoder {
    MockURLProtocol.handler = { request in
        captured.request = request
        return try handler(request)
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    let cacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ORSTests-\(UUID().uuidString)", isDirectory: true)
    let cache = GeocoderCache(cacheDirectory: cacheDirectory)
    return OpenRouteServiceGeocoder(session: session, cache: cache)
}
