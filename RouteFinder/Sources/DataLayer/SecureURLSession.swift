import Foundation

/// URLSession configured for TLS-only network access.
public enum SecureURLSession {
    /// Shared session that rejects non-HTTPS requests at the delegate layer.
    public static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: TLSOnlyDelegate(), delegateQueue: nil)
    }()
}

private final class TLSOnlyDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, url.scheme?.lowercased() == "https" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

extension URLRequest {
    /// Returns false when the URL scheme is not HTTPS.
    public var isSecureHTTPS: Bool {
        url?.scheme?.lowercased() == "https"
    }
}
