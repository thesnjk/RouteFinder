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

/// Starts an SSE subscription before trip push so the client is attached before the event fires.
///
/// Settles briefly after opening the stream so URLSession can connect (replaces ad-hoc 200 ms
/// sleeps scattered in callers).
func beginSSESubscription(
    baseURL: URL,
    apiKey: String?,
    vehicleId: UUID,
    tripPushedOnly: Bool = false,
    settleNanoseconds: UInt64 = 100_000_000
) async -> Task<FleetDispatchEvent?, Never> {
    let stream = FleetSSEClient.events(baseURL: baseURL, apiKey: apiKey, vehicleId: vehicleId)
    let receiveTask = Task<FleetDispatchEvent?, Never> {
        for await event in stream {
            if tripPushedOnly, event.kind != .tripPushed {
                continue
            }
            return event
        }
        return nil
    }
    if settleNanoseconds > 0 {
        try? await Task.sleep(nanoseconds: settleNanoseconds)
    }
    return receiveTask
}

/// Awaits the first SSE event from a subscription task, or `nil` if `timeoutNanoseconds` elapses.
func awaitSSEEvent(
    _ receiveTask: Task<FleetDispatchEvent?, Never>,
    timeoutNanoseconds: UInt64 = 5_000_000_000
) async throws -> FleetDispatchEvent? {
    try await withThrowingTaskGroup(of: FleetDispatchEvent?.self) { group in
        group.addTask { await receiveTask.value }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            return nil
        }
        guard let first = try await group.next() else { return nil }
        group.cancelAll()
        return first
    }
}
