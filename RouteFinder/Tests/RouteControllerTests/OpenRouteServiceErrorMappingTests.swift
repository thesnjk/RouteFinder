import Contracts
import Foundation
import Testing
@testable import RouteController

@Suite("ORS error mapping", .serialized)
struct OpenRouteServiceErrorMappingTests {
    private let routeRequest = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: .ukArtic,
        preferences: RoutingPreferences(isHGVMode: true)
    )

    @Test("bridge height message maps to vehicleDimensionBlocked")
    func dimensionBlockedByKeyword() async throws {
        let body = """
        {"error":{"code":2004,"message":"Exceeded bridge height clearance on corridor"}}
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 400, body: body)

        do {
            _ = try await client.route(request: routeRequest)
            Issue.record("Expected vehicleDimensionBlocked")
        } catch let error as ExternalRoutingError {
            if case .vehicleDimensionBlocked(let reason) = error {
                #expect(reason.contains("bridge height"))
            } else {
                Issue.record("Expected vehicleDimensionBlocked, got \(error)")
            }
        }
    }

    @Test("restriction keyword maps to vehicleDimensionBlocked")
    func dimensionBlockedByRestriction() async throws {
        let body = """
        {"error":{"code":2004,"message":"Vehicle restriction on corridor"}}
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 400, body: body)

        do {
            _ = try await client.route(request: routeRequest)
            Issue.record("Expected vehicleDimensionBlocked")
        } catch let error as ExternalRoutingError {
            if case .vehicleDimensionBlocked = error {
                #expect(error.errorDescription == ExternalRoutingError.vehicleDimensionBlockedMessage)
            } else {
                Issue.record("Expected vehicleDimensionBlocked, got \(error)")
            }
        }
    }

    @Test("generic no-route message maps to noRoute")
    func genericNoRoute() async throws {
        let body = """
        {"error":{"code":2004,"message":"Route could not be found between these locations"}}
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 400, body: body)

        do {
            _ = try await client.route(request: routeRequest)
            Issue.record("Expected noRoute")
        } catch let error as ExternalRoutingError {
            if case .noRoute = error {
                #expect(error.errorDescription == ExternalRoutingError.hgvNoRouteMessage)
            } else {
                Issue.record("Expected noRoute, got \(error)")
            }
        }
    }

    @Test("parses successful GeoJSON LineString response")
    func successResponse() async throws {
        let body = """
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [[1.0, 52.0], [1.1, 52.1]]
            },
            "properties": {
              "summary": { "distance": 15000, "duration": 1200 }
            }
          }]
        }
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 200, body: body)

        let response = try await client.route(request: routeRequest)
        #expect(response.coordinates.count == 2)
        #expect(response.coordinates[0].latitude == 52.0)
        #expect(response.coordinates[0].longitude == 1.0)
        #expect(response.distanceMeters == 15000)
        #expect(response.durationSeconds == 1200)
        #expect(response.encodedPolyline == nil)
    }

    private func makeClient(statusCode: Int, body: Data) throws -> OpenRouteServiceRoutingClient {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return try OpenRouteServiceRoutingClient(
            apiKey: "test-api-key",
            session: URLSession(configuration: config)
        )
    }
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
