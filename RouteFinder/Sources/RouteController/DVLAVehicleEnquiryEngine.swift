import Contracts
import DataLayer
import Foundation

/// UK DVLA Vehicle Enquiry Service REST engine.
public struct DVLAVehicleEnquiryEngine: Sendable {
    private static let baseURL = URL(string: "https://driver-vehicle-licensing.api.gov.uk/v1/vehicles")!

    private let apiKey: String
    private let session: URLSession

    /// Creates a DVLA enquiry engine with the given API key.
    public init(apiKey: String, session: URLSession = SecureURLSession.shared) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VehicleRegistryError.notConfigured
        }
        self.apiKey = trimmed
        self.session = session
    }

    /// Looks up a UK registration via the DVLA VES API.
    public func lookup(registration: String) async throws -> DVLAVehicleResponse {
        let normalized = RegistrationNormalizer.normalize(registration)
        guard !normalized.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }

        var request = URLRequest(url: Self.baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(DVLARequestBody(registrationNumber: normalized))

        guard request.isSecureHTTPS else {
            throw VehicleRegistryError.invalidConfiguration
        }

        let policy = RemoteRequestPolicy.default
        let (data, http) = try await policy.data(for: request, session: session)
        switch http.statusCode {
        case 200:
            await APIUsageLedger.shared.record(provider: .dvla)
            return try decodeResponse(data)
        case 404:
            throw VehicleRegistryError.notFound(registration: normalized)
        case 401, 403:
            throw VehicleRegistryError.notConfigured
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw VehicleRegistryError.networkFailure("HTTP \(http.statusCode): \(body)")
        }
    }

    private func decodeResponse(_ data: Data) throws -> DVLAVehicleResponse {
        do {
            return try JSONDecoder().decode(DVLAVehicleResponse.self, from: data)
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "DVLA vehicle response",
                responsePreview: DecodingDiagnostics.preview(of: data)
            )
            throw VehicleRegistryError.decodingFailed(error.localizedDescription)
        }
    }

}

private struct DVLARequestBody: Encodable {
    let registrationNumber: String
}
