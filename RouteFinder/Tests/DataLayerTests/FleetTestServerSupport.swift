import Contracts
import DataLayer
import Foundation
import Testing

/// Polls `GET /health` until the fleet server accepts connections or the timeout elapses.
///
/// Replaces fixed `Task.sleep` startup waits that flake on GitHub Actions when Hummingbird
/// takes longer than ~300 ms to bind.
func waitForFleetServerReady(
    baseURL: URL,
    timeoutNanoseconds: UInt64 = 10_000_000_000,
    pollIntervalNanoseconds: UInt64 = 50_000_000
) async throws {
    let client = HTTPFleetStore(baseURL: baseURL)
    var elapsed: UInt64 = 0
    var lastError: Error?
    while elapsed < timeoutNanoseconds {
        do {
            let health = try await client.checkHealth()
            if health.ok {
                return
            }
            lastError = HTTPFleetStoreError.serverError(status: 503, body: "health.ok == false")
        } catch {
            lastError = error
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        elapsed += pollIntervalNanoseconds
    }
    Issue.record("Fleet server at \(baseURL) did not become ready in time. Last error: \(String(describing: lastError))")
    throw lastError ?? HTTPFleetStoreError.serverError(status: 503, body: "timeout waiting for health")
}
