import Foundation

/// Request body for creating a fleet organisation via the HTTP fleet API.
public struct CreateOrgRequest: Codable, Sendable {
    /// Display name for the organisation.
    public let name: String

    /// Creates a create-org request payload.
    public init(name: String) {
        self.name = name
    }
}

/// Health check response from the fleet HTTP server.
public struct FleetServerHealthResponse: Codable, Sendable, Equatable {
    /// True when the server is accepting requests.
    public let ok: Bool
    /// API version string.
    public let version: String

    /// Creates a health response.
    public init(ok: Bool, version: String) {
        self.ok = ok
        self.version = version
    }
}

/// JSON error payload returned by the fleet HTTP server.
public struct FleetErrorResponse: Codable, Sendable, Equatable {
    /// Human-readable error message.
    public let error: String

    /// Creates a fleet error payload.
    public init(error: String) {
        self.error = error
    }
}
