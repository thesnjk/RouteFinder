import Contracts
import Foundation

/// Builds ORS routing and Pelias geocoding clients that target the fleet server proxy when configured.
public enum FleetORSRoutingFactory {
    /// Shared-secret sent to the fleet server when `--api-key` is enabled (Bearer auth).
    public static func fleetProxyAuthKey(fleetAPIKey: String?) -> String {
        let auth = fleetAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (auth?.isEmpty == false) ? auth! : "fleet-proxy"
    }

    /// Pelias base URL on the fleet server (`…/v1/proxy/pelias/v1`).
    public static func fleetProxyPeliasBaseURL(fleetServerURL: URL) -> URL {
        fleetServerURL
            .appendingPathComponent("v1")
            .appendingPathComponent("proxy")
            .appendingPathComponent("pelias")
            .appendingPathComponent("v1")
    }
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
            let key = fleetProxyAuthKey(fleetAPIKey: fleetAPIKey)
            return try OpenRouteServiceRoutingClient(
                apiKey: key,
                baseURL: proxyBase,
                session: URLSession.shared,
                allowLANHTTP: true,
                useBearerAuthorization: true
            )
        }

        return try OpenRouteServiceRoutingClient(apiKey: localORSAPIKey)
    }

    /// Creates a Pelias geocoder: fleet proxy when remote fleet is enabled, else direct HeiGIT.
    public static func makeGeocoder(
        localORSAPIKey: String,
        useRemoteFleetServer: Bool,
        fleetServerURL: URL?,
        fleetAPIKey: String?
    ) -> OpenRouteServiceGeocoder {
        if useRemoteFleetServer, let fleetServerURL {
            let proxyBase = fleetProxyPeliasBaseURL(fleetServerURL: fleetServerURL)
            let key = fleetProxyAuthKey(fleetAPIKey: fleetAPIKey)
            return OpenRouteServiceGeocoder(
                baseURL: proxyBase,
                session: URLSession.shared,
                fleetProxyAuthKey: key,
                allowLANHTTP: true
            )
        }

        return OpenRouteServiceGeocoder()
    }

    /// Whether cloud routing and geocoding can proceed without a local HeiGIT key.
    public static func usesFleetProxy(
        useRemoteFleetServer: Bool,
        fleetServerURL: URL?
    ) -> Bool {
        useRemoteFleetServer && fleetServerURL != nil
    }
}
