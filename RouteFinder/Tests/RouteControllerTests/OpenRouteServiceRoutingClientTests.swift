import Contracts
import Foundation
import Testing
@testable import RouteController

@Suite("ORS maxspeed decode", .serialized)
struct OpenRouteServiceRoutingClientTests {
    private let routeRequest = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.628, longitude: 1.296),
        destination: RoutingCoordinate(latitude: 52.630, longitude: 1.300),
        vehicle: .default,
        preferences: RoutingPreferences(isHGVMode: false, requestSegmentSpeedLimits: true)
    )

    @Test("parses geometry extras maxspeed and step way_points ranges")
    func maxspeedExtrasAndStepRanges() async throws {
        let body = """
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [10.70, 59.90],
                [10.72, 59.91],
                [10.74, 59.92]
              ]
            },
            "properties": {
              "summary": { "distance": 5000, "duration": 300 },
              "extras": {
                "maxspeed": [50, 80, 110]
              },
              "segments": [{
                "steps": [{
                  "instruction": "Continue on E6",
                  "distance": 5000,
                  "duration": 300,
                  "type": 11,
                  "way_points": [0, 2],
                  "maximum_speed": 110
                }]
              }]
            }
          }]
        }
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 200, body: body)

        let response = try await client.route(request: routeRequest)

        #expect(response.coordinates.count == 3)
        let source = try #require(response.speedLimitSource)
        #expect(source.rawGeometrySpeedLimitsKmh.count == 3)
        #expect(source.rawGeometrySpeedLimitsKmh[0] == 50)
        #expect(source.rawGeometrySpeedLimitsKmh[1] == 80)
        #expect(source.rawGeometrySpeedLimitsKmh[2] == 110)
        #expect(source.stepSpeedRanges.count == 1)
        #expect(source.stepSpeedRanges[0].startIndex == 0)
        #expect(source.stepSpeedRanges[0].endIndex == 2)
        #expect(source.stepSpeedRanges[0].speedLimitKmh != nil)
        #expect(response.maneuvers.count == 1)
        #expect(response.maneuvers[0].speedLimitKmh != nil)
    }

    @Test("parses string maxspeed values from extras")
    func stringMaxspeedValues() async throws {
        let body = """
        {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [[1.296, 52.628], [1.300, 52.630]]
            },
            "properties": {
              "summary": { "distance": 2000, "duration": 120 },
              "extras": {
                "maxspeed": ["30 mph", "60 mph"]
              }
            }
          }]
        }
        """.data(using: .utf8)!
        let client = try makeClient(statusCode: 200, body: body)

        let response = try await client.route(request: routeRequest)
        let source = try #require(response.speedLimitSource)

        #expect(source.rawGeometrySpeedLimitsKmh.count == 2)
        #expect(abs((source.rawGeometrySpeedLimitsKmh[0] ?? 0) - 48.0) < 1.0)
        #expect(abs((source.rawGeometrySpeedLimitsKmh[1] ?? 0) - 96.5604) < 1.0)
    }

    private func makeClient(statusCode: Int, body: Data) throws -> OpenRouteServiceRoutingClient {
        ORSMaxspeedMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ORSMaxspeedMockURLProtocol.self]
        return try OpenRouteServiceRoutingClient(
            apiKey: "test-api-key",
            session: URLSession(configuration: config)
        )
    }
}

private final class ORSMaxspeedMockURLProtocol: URLProtocol, @unchecked Sendable {
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
