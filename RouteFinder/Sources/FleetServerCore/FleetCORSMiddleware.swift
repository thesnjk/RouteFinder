import Foundation
import HTTPTypes
import Hummingbird

private enum FleetCORSHeaderValues {
    static let allowOrigin = "*"
    static let allowMethods = "GET, POST, PUT, OPTIONS"
    static let allowHeaders = "Authorization, Content-Type, X-Fleet-API-Key"
}

private let accessControlAllowMethods = HTTPField.Name("Access-Control-Allow-Methods")!
private let accessControlAllowHeaders = HTTPField.Name("Access-Control-Allow-Headers")!

/// Allows browser LAN consoles (e.g. Vite on :5173) to call the fleet API on :8080.
public struct FleetCORSMiddleware<Context: RequestContext>: MiddlewareProtocol {
    /// Creates fleet CORS middleware for LAN browser clients.
    public init() {}

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        if request.method == .options {
            var headers = HTTPFields()
            applyCORSHeaders(to: &headers)
            return Response(status: .noContent, headers: headers)
        }

        var response = try await next(request, context)
        applyCORSHeaders(to: &response.headers)
        return response
    }

    private func applyCORSHeaders(to headers: inout HTTPFields) {
        headers[.accessControlAllowOrigin] = FleetCORSHeaderValues.allowOrigin
        headers[accessControlAllowMethods] = FleetCORSHeaderValues.allowMethods
        headers[accessControlAllowHeaders] = FleetCORSHeaderValues.allowHeaders
    }
}
