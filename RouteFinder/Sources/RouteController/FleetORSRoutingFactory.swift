import Contracts
import Foundation

/// Builds an ORS routing client that targets the fleet server proxy when configured.
public enum FleetORSRoutingFactory {
    /// Creates a routing client: fleet ORS proxy when remote fleet is enabled, else direct HeiGIT.
    ///
    /// - Parameters:
    ///   - localORSAPIKey: Device Keychain ORS key (may be empty when using operator-paid proxy).
    ///   - useRemoteFleetServer: Whether fleet LAN sync / proxy is enabled.
    ///   - fleetServerURL: Base URL of `RouteFinderFleetServer`.
    ///   - fleetAPIKey: Optional shared-secret for fleet auth (also sent as ORS Authorization to the proxy).
    public static func makeRoutingClient(
        localORSAPIKey: String,
        useRemoteFleetServer: Bool,
        fleetServerURL: URL?,
        fleetAPIKey: String?
    ) throws -> OpenRouteServiceRoutingClient {
        if useRemoteFleetServer, let fleetServerURL {
            let proxyBase = fleetServerURL
                .appendingPathComponent("v1")
                .appendingPathComponent("proxy")
                .appendingPathComponent("ors")
                .appendingPathComponent("v2")
            let auth = fleetAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = (auth?.isEmpty == false) ? auth! : "fleet-proxy"
            return try OpenRouteServiceRoutingClient(
                apiKey: key,
                baseURL: proxyBase,
                session: URLSession.shared,
                allowLANHTTP: true
            )
        }

        return try OpenRouteServiceRoutingClient(apiKey: localORSAPIKey)
    }

    /// Whether cloud routing can proceed without a local HeiGIT key.
    public static func usesFleetProxy(
        useRemoteFleetServer: Bool,
        fleetServerURL: URL?
    ) -> Bool {
        useRemoteFleetServer && fleetServerURL != nil
    }
}
