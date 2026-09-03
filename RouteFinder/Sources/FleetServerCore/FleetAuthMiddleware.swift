import Contracts
import Foundation
import HTTPTypes
import Hummingbird

private let fleetAPIKeyHeader = HTTPField.Name("X-Fleet-API-Key")!

/// Shared-secret authentication for fleet REST routes.
public struct FleetAuthMiddleware<Context: RequestContext>: MiddlewareProtocol {
    private let apiKey: String

    /// Creates middleware that requires the given API key on protected routes.
    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Browser CORS preflight must not require an API key.
        if request.method == .options {
            return try await next(request, context)
        }
        guard matchesConfiguredKey(extractAPIKey(from: request)) else {
            return unauthorizedResponse()
        }
        return try await next(request, context)
    }

    private func extractAPIKey(from request: Request) -> String? {
        if let authorization = request.headers[values: .authorization].first {
            let prefix = "Bearer "
            if authorization.hasPrefix(prefix) {
                return String(authorization.dropFirst(prefix.count))
            }
        }
        if let header = request.headers[values: fleetAPIKeyHeader].first {
            return header
        }
        return nil
    }

    private func matchesConfiguredKey(_ provided: String?) -> Bool {
        guard let provided, !provided.isEmpty else { return false }
        return provided == apiKey
    }

    private func unauthorizedResponse() -> Response {
        let payload = FleetErrorResponse(error: "Unauthorized")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else {
            return Response(status: .unauthorized)
        }
        var buffer = ByteBuffer()
        buffer.writeData(data)
        var headers = HTTPFields()
        headers[.contentType] = "application/json; charset=utf-8"
        return Response(status: .unauthorized, headers: headers, body: .init(byteBuffer: buffer))
    }
}
