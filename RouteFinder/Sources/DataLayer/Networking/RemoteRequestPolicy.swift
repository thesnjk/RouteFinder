import Foundation
import os

/// Unified retry, backoff, and timeout policy for outbound HTTP calls.
public struct RemoteRequestPolicy: Sendable {
    /// Per-attempt timeout in seconds.
    public var timeoutInterval: TimeInterval
    /// Maximum retry attempts after the first request (0 = no retries).
    public var maxRetries: Int
    /// Initial backoff before the first retry.
    public var initialBackoff: TimeInterval
    /// Upper bound for exponential backoff between retries.
    public var maxBackoff: TimeInterval

    /// Default policy: 30s timeout, one retry with jittered backoff.
    public static let `default` = RemoteRequestPolicy(
        timeoutInterval: 30,
        maxRetries: 1,
        initialBackoff: 0.5,
        maxBackoff: 8
    )

    /// Creates a remote request policy.
    public init(
        timeoutInterval: TimeInterval = 30,
        maxRetries: Int = 1,
        initialBackoff: TimeInterval = 0.5,
        maxBackoff: TimeInterval = 8
    ) {
        self.timeoutInterval = timeoutInterval
        self.maxRetries = max(0, maxRetries)
        self.initialBackoff = max(0, initialBackoff)
        self.maxBackoff = max(initialBackoff, maxBackoff)
    }

    /// Executes a URLSession request with retries for transient failures and HTTP 429.
    public func data(
        for request: URLRequest,
        session: URLSession,
        logger: Logger? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var backoff = initialBackoff
        var lastError: Error?

        while attempt <= maxRetries {
            var attemptRequest = request
            attemptRequest.timeoutInterval = timeoutInterval

            do {
                let (data, response) = try await session.data(for: attemptRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw RemoteRequestPolicyError.invalidResponse
                }

                if http.statusCode == 429 || (500 ... 599).contains(http.statusCode) {
                    if attempt < maxRetries {
                        let delay = retryDelay(
                            statusCode: http.statusCode,
                            response: http,
                            backoff: backoff
                        )
                        logger?.info("Retrying HTTP \(http.statusCode) in \(delay, privacy: .public)s (attempt \(attempt + 1))")
                        try await sleep(seconds: delay)
                        backoff = min(backoff * 2, maxBackoff)
                        attempt += 1
                        continue
                    }
                }

                return (data, http)
            } catch {
                lastError = error
                if attempt < maxRetries, isRetriable(error) {
                    let delay = jittered(backoff)
                    logger?.info("Retrying transport error in \(delay, privacy: .public)s (attempt \(attempt + 1))")
                    try await sleep(seconds: delay)
                    backoff = min(backoff * 2, maxBackoff)
                    attempt += 1
                    continue
                }
                throw error
            }
        }

        throw lastError ?? RemoteRequestPolicyError.exhaustedRetries
    }

    private func retryDelay(statusCode: Int, response: HTTPURLResponse, backoff: TimeInterval) -> TimeInterval {
        if statusCode == 429, let retryAfter = parseRetryAfter(from: response) {
            return retryAfter
        }
        return jittered(backoff)
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private func jittered(_ base: TimeInterval) -> TimeInterval {
        let jitter = Double.random(in: 0...(base * 0.25))
        return base + jitter
    }

    private func isRetriable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func sleep(seconds: TimeInterval) async throws {
        let nanos = UInt64(max(0, seconds) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }
}

/// Errors from ``RemoteRequestPolicy``.
public enum RemoteRequestPolicyError: Error, Sendable {
    case invalidResponse
    case exhaustedRetries
}

/// Shared OSLog categories for remote services.
public enum RouteFinderLog {
    public static let routing = Logger(subsystem: "com.routefinder.app", category: "routing")
    public static let geocode = Logger(subsystem: "com.routefinder.app", category: "geocode")
    public static let fleet = Logger(subsystem: "com.routefinder.app", category: "fleet")
    public static let metering = Logger(subsystem: "com.routefinder.app", category: "metering")
}
