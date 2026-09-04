import Foundation
import Hummingbird
import NIOCore

/// Proxies HeiGIT OpenRouteService / Pelias calls using the operator-held API key.
public enum FleetORSProxy {
    /// Upstream ORS v2 base.
    public static let orsUpstreamBase = "https://api.heigit.org/openrouteservice/v2"
    /// Upstream Pelias v1 base.
    public static let peliasUpstreamBase = "https://api.heigit.org/pelias/v1"

    /// Registers `/v1/proxy/*` routes when an ORS key is configured.
    public static func registerRoutes(
        on router: Router<BasicRequestContext>,
        orsAPIKey: String?,
        meter: FleetProxyUsageMeter,
        session: URLSession = .shared
    ) {
        let trimmed = orsAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let configured = !trimmed.isEmpty

        router.get("v1/proxy/status") { _, _ async throws -> Response in
            let status = await meter.status(orsConfigured: configured)
            return try jsonResponse(status)
        }

        guard configured else { return }

        router.post("v1/proxy/ors/v2/directions/driving-hgv/geojson") { request, _ async throws -> Response in
            try await proxyORSPOST(
                path: "directions/driving-hgv/geojson",
                request: request,
                orsAPIKey: trimmed,
                meter: meter,
                session: session
            )
        }

        router.post("v1/proxy/ors/v2/directions/driving-car/geojson") { request, _ async throws -> Response in
            try await proxyORSPOST(
                path: "directions/driving-car/geojson",
                request: request,
                orsAPIKey: trimmed,
                meter: meter,
                session: session
            )
        }

        router.post("v1/proxy/ors/v2/matrix/driving-hgv") { request, _ async throws -> Response in
            try await proxyORSPOST(
                path: "matrix/driving-hgv",
                request: request,
                orsAPIKey: trimmed,
                meter: meter,
                session: session
            )
        }

        router.post("v1/proxy/ors/v2/matrix/driving-car") { request, _ async throws -> Response in
            try await proxyORSPOST(
                path: "matrix/driving-car",
                request: request,
                orsAPIKey: trimmed,
                meter: meter,
                session: session
            )
        }

        router.get("v1/proxy/pelias/v1/search") { request, _ async throws -> Response in
            guard await meter.allows(.orsGeocode) else {
                throw HTTPError(.tooManyRequests, message: "Fleet ORS geocode daily cap reached.")
            }
            guard var components = URLComponents(string: "\(peliasUpstreamBase)/search") else {
                throw HTTPError(.badRequest, message: "Invalid geocode upstream.")
            }
            components.percentEncodedQuery = request.uri.query
            guard let url = components.url else {
                throw HTTPError(.badRequest, message: "Invalid geocode query.")
            }
            var upstream = URLRequest(url: url)
            upstream.httpMethod = "GET"
            upstream.setValue(trimmed, forHTTPHeaderField: "Authorization")
            upstream.setValue("application/json", forHTTPHeaderField: "Accept")
            upstream.setValue("RouteFinderFleetServer/1.0", forHTTPHeaderField: "User-Agent")
            await meter.record(.orsGeocode)
            return try await forward(upstream, session: session)
        }
    }

    private static func proxyORSPOST(
        path: String,
        request: Request,
        orsAPIKey: String,
        meter: FleetProxyUsageMeter,
        session: URLSession
    ) async throws -> Response {
        guard await meter.allows(.orsRoute) else {
            throw HTTPError(.tooManyRequests, message: "Fleet ORS route daily cap reached.")
        }
        guard let url = URL(string: "\(orsUpstreamBase)/\(path)") else {
            throw HTTPError(.badRequest, message: "Invalid ORS upstream.")
        }
        var upstream = URLRequest(url: url)
        upstream.httpMethod = "POST"
        upstream.setValue(orsAPIKey, forHTTPHeaderField: "Authorization")
        upstream.setValue("application/json", forHTTPHeaderField: "Content-Type")
        upstream.setValue("application/json", forHTTPHeaderField: "Accept")
        upstream.setValue("RouteFinderFleetServer/1.0", forHTTPHeaderField: "User-Agent")
        upstream.httpBody = try await collectBodyData(request)
        await meter.record(.orsRoute)
        return try await forward(upstream, session: session)
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
            throw HTTPError(.badGateway, message: "Upstream ORS returned a non-HTTP response.")
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

    private static func jsonResponse<T: Encodable>(_ value: T) throws -> Response {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        var buffer = ByteBuffer()
        buffer.writeData(data)
        var headers = HTTPFields()
        headers[.contentType] = "application/json; charset=utf-8"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: buffer))
    }
}
