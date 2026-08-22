import Foundation

/// Errors from vehicle registration plate lookup.
public enum VehicleRegistryError: Error, Sendable, LocalizedError {
    case emptyRegistration
    case notConfigured
    case invalidConfiguration
    case networkFailure(String)
    case notFound(registration: String)
    case decodingFailed(String)
    case unsupportedRegion

    public var errorDescription: String? {
        switch self {
        case .emptyRegistration:
            return "Enter a registration number."
        case .notConfigured:
            return "Vehicle registry API key is not configured."
        case .invalidConfiguration:
            return "Vehicle registry client configuration is invalid."
        case .networkFailure(let detail):
            return "Registry lookup failed: \(detail)"
        case .notFound(let registration):
            return "No profile found for “\(registration)”."
        case .decodingFailed(let detail):
            return "Could not parse registry response: \(detail)"
        case .unsupportedRegion:
            return "Registration format is not supported for live lookup."
        }
    }
}

/// Geographic region hint for vehicle registry routing.
public enum VehicleRegistryRegion: String, Codable, Sendable, Hashable, CaseIterable {
    /// Detect region from plate format.
    case auto
    /// United Kingdom (RegCheck / DVLA fallback).
    case uk
    /// European Union formats.
    case eu
    /// United States formats.
    case us
}
