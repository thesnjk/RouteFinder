import Foundation

/// URLSession for fleet LAN sync supporting HTTP and HTTPS (TLS 1.2+).
public enum FleetURLSession {
    /// Shared session for fleet HTTP/HTTPS requests.
    public static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
}
