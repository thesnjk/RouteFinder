import Foundation

/// Bonjour service metadata for fleet LAN discovery.
public enum FleetBonjour {
    /// Bonjour service type for the fleet HTTP server.
    public static let serviceType = "_routefinder-fleet._tcp"
    /// TXT record key indicating TLS is enabled on the advertised port.
    public static let txtTLSKey = "tls"
    /// TXT record key for fleet API version.
    public static let txtVersionKey = "version"

    /// Builds a fleet server base URL from resolved host metadata.
    public static func baseURL(host: String, port: Int, usesTLS: Bool) -> URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, port > 0, port <= 65_535 else { return nil }

        let scheme = usesTLS ? "https" : "http"
        let hostPart: String
        if trimmedHost.contains(":"), !trimmedHost.hasPrefix("[") {
            hostPart = "[\(trimmedHost)]"
        } else {
            hostPart = trimmedHost
        }
        return URL(string: "\(scheme)://\(hostPart):\(port)")
    }

    /// Returns whether a Bonjour TXT record indicates TLS.
    public static func usesTLS(fromTXTRecord txtRecord: [String: Data]?) -> Bool {
        guard let txtRecord,
              let value = txtRecord[txtTLSKey],
              let flag = String(data: value, encoding: .utf8) else {
            return false
        }
        return flag == "1"
    }
}

/// A fleet server discovered via Bonjour on the local network.
public struct DiscoveredFleetServer: Sendable, Identifiable, Equatable {
    /// Stable identifier for SwiftUI lists.
    public let id: String
    /// Human-readable Bonjour service name.
    public let displayName: String
    /// Resolved fleet server base URL.
    public let baseURL: URL

    /// Creates a discovered fleet server entry.
    public init(id: String, displayName: String, baseURL: URL) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
    }
}
