import Foundation

/// Shared HTTP identity for OSM-facing and routing clients.
public enum NetworkClientIdentity {
    /// User-Agent required by Nominatim usage policy and recommended for tile/routing servers.
    public static let userAgent = "RouteFinderLogisticsApp/1.0 (contact@yourdomain.com)"
}

extension URLRequest {
    /// Applies the app User-Agent and JSON accept header to outbound requests.
    public mutating func applyAppIdentity() {
        setValue(NetworkClientIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        setValue("application/json", forHTTPHeaderField: "Accept")
    }
}
