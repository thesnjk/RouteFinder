import DataLayer
import Foundation
import Testing

@Suite("RemoteRequestPolicy", .serialized)
struct RemoteRequestPolicyTests {
    @Test func retries429UntilSuccess() async throws {
        let session = try makeSession { request in
            MockURLProtocol.requestCount += 1
            if MockURLProtocol.requestCount == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "0"]
                )!
                return (Data(), response)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("ok".utf8), response)
        }

        let policy = RemoteRequestPolicy(timeoutInterval: 5, maxRetries: 2, initialBackoff: 0.01, maxBackoff: 0.05)
        var request = URLRequest(url: URL(string: "https://example.com/route")!)
        let (_, http) = try await policy.data(for: request, session: session)
        #expect(http.statusCode == 200)
        #expect(MockURLProtocol.requestCount == 2)
    }

    @Test func respectsMaxRetries() async throws {
        MockURLProtocol.requestCount = 0
        let session = try makeSession { request in
            MockURLProtocol.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let policy = RemoteRequestPolicy(timeoutInterval: 5, maxRetries: 1, initialBackoff: 0.01, maxBackoff: 0.02)
        var request = URLRequest(url: URL(string: "https://example.com/route")!)
        let (_, http) = try await policy.data(for: request, session: session)
        #expect(http.statusCode == 503)
        #expect(MockURLProtocol.requestCount == 2)
    }

    @Test func backoffCapUsesMaxBackoff() async {
        let policy = RemoteRequestPolicy(initialBackoff: 4, maxBackoff: 5)
        #expect(policy.maxBackoff == 5)
    }

    private func makeSession(
        handler: @escaping (URLRequest) -> (Data, URLResponse)
    ) throws -> URLSession {
        MockURLProtocol.requestCount = 0
        MockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Data, URLResponse))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (data, response) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
