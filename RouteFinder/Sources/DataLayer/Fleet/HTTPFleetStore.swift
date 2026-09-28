import Contracts
import Foundation

/// Errors from the HTTP fleet dispatch client.
public enum HTTPFleetStoreError: Error, Sendable, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(status: Int, body: String)
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Fleet server URL is invalid."
        case .invalidResponse:
            return "Fleet server returned an unexpected response."
        case .serverError(let status, let body):
            let preview = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if status == 401 || status == 403 {
                let base = "Fleet API key rejected. Check the shared key with the operator."
                if preview.isEmpty { return base }
                let lower = preview.lowercased()
                if lower.contains("unauthorized") || lower.contains("forbidden") {
                    return base
                }
                return "\(base) (\(preview.prefix(120)))"
            }
            if preview.isEmpty {
                return "Fleet server error (HTTP \(status))."
            }
            return "Fleet server error (HTTP \(status)): \(preview.prefix(160))"
        case .decodingFailed:
            return "Could not decode the fleet server response."
        }
    }
}

/// Remote fleet store backed by the LAN Hummingbird fleet API.
public actor HTTPFleetStore: FleetDispatchPort {
    private let baseURL: URL
    private let apiKey: String?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates an HTTP fleet client for the given server base URL.
    public init(
        baseURL: URL,
        apiKey: String? = nil,
        session: URLSession = FleetURLSession.shared
    ) {
        var normalized = baseURL
        if normalized.path.hasSuffix("/") {
            normalized.deleteLastPathComponent()
        }
        self.baseURL = normalized
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Pings the fleet server health endpoint.
    public func checkHealth() async throws -> FleetServerHealthResponse {
        try await get(path: "health")
    }

    /// Probes a protected route so pairing cannot report Connected on public `/health` alone
    /// when the server requires `--api-key`.
    public func verifyAuthenticatedAccess() async throws {
        _ = try await fetchProxyStatus()
    }

    /// Reads full desk metering from `/v1/proxy/status` (ORS + forecast caps).
    public func fetchProxyStatus() async throws -> FleetProxyDeskStatus {
        let (data, response) = try await rawRequest(path: "v1/proxy/status", method: "GET")
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(FleetProxyDeskStatus.self, from: data)
    }

    /// Reads forecast proxy capability flags from `/v1/proxy/status` (TomTom / OpenWeather).
    public func fetchForecastProxyCapabilities() async throws -> FleetForecastProxyCapabilities {
        let status = try await fetchProxyStatus()
        return FleetForecastProxyCapabilities(
            tomTomConfigured: status.tomTomConfigured,
            openWeatherConfigured: status.openWeatherConfigured
        )
    }

    public func createOrg(name: String) async throws -> FleetOrg {
        try await post(path: "v1/orgs", body: CreateOrgRequest(name: name))
    }

    public func registerVehicle(_ vehicle: FleetVehicle) async throws -> FleetVehicle {
        try await post(path: "v1/vehicles", body: vehicle)
    }

    public func pushTrip(_ trip: FleetTrip) async throws -> FleetTrip {
        try await post(path: "v1/trips", body: trip)
    }

    public func activeTrip(forVehicleId vehicleId: UUID) async throws -> FleetTrip? {
        let (data, response) = try await rawRequest(
            path: "v1/vehicles/\(vehicleId.uuidString)/active-trip",
            method: "GET"
        )
        if response.statusCode == 204 || data.isEmpty {
            return nil
        }
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(FleetTrip.self, from: data)
    }

    public func applySnapshot(_ snapshot: FleetTripSnapshot) async throws -> FleetTrip {
        try await put(path: "v1/trips/\(snapshot.tripId.uuidString)/snapshot", body: snapshot)
    }

    public func orgs() async throws -> [FleetOrg] {
        try await get(path: "v1/orgs")
    }

    public func vehicles(forOrgId orgId: UUID) async throws -> [FleetVehicle] {
        try await get(path: "v1/orgs/\(orgId.uuidString)/vehicles")
    }

    public func createAndPushTrip(
        orgId: UUID,
        vehicleId: UUID,
        stops: [FleetTripStop],
        companyBreaks: [CompanyBreakAllocation] = [],
        vehicleProfile: VehicleProfile? = nil,
        jobBrief: FleetJobBrief? = nil
    ) async throws -> FleetTrip {
        let trip = try FleetTripBuilder.makeTrip(
            orgId: orgId,
            vehicleId: vehicleId,
            stops: stops,
            companyBreaks: companyBreaks,
            vehicleProfile: vehicleProfile,
            jobBrief: jobBrief
        )
        return try await pushTrip(trip)
    }

    public func trip(id: UUID) async throws -> FleetTrip? {
        let (data, response) = try await rawRequest(path: "v1/trips/\(id.uuidString)", method: "GET")
        if response.statusCode == 404 {
            return nil
        }
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(FleetTrip.self, from: data)
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let (data, response) = try await rawRequest(path: path, method: "GET")
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(T.self, from: data)
    }

    private func post<T: Decodable, Body: Encodable>(path: String, body: Body) async throws -> T {
        let bodyData = try encoder.encode(body)
        let (data, response) = try await rawRequest(path: path, method: "POST", body: bodyData)
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(T.self, from: data)
    }

    private func put<T: Decodable, Body: Encodable>(path: String, body: Body) async throws -> T {
        let bodyData = try encoder.encode(body)
        let (data, response) = try await rawRequest(path: path, method: "PUT", body: bodyData)
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data)
        }
        return try decode(T.self, from: data)
    }

    private func rawRequest(path: String, method: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw HTTPFleetStoreError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let policy = RemoteRequestPolicy(
            timeoutInterval: 30,
            maxRetries: 2,
            initialBackoff: 0.5,
            maxBackoff: 15
        )
        let (data, http) = try await policy.data(
            for: request,
            session: session,
            logger: RouteFinderLog.fleet
        )
        return (data, http)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw HTTPFleetStoreError.decodingFailed
        }
    }

    private func mapError(status: Int, data: Data) -> Error {
        if status == 404 {
            return FleetStoreError.tripNotFound
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        return HTTPFleetStoreError.serverError(status: status, body: body)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
