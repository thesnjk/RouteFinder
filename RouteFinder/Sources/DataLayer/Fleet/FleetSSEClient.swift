import Contracts
import Foundation

/// Client for fleet dispatch server-sent events over HTTP.
public enum FleetSSEClient {
    /// Opens an SSE stream for dispatch events affecting the given vehicle.
    public static func events(
        baseURL: URL,
        apiKey: String?,
        vehicleId: UUID,
        session: URLSession = FleetURLSession.shared
    ) -> AsyncStream<FleetDispatchEvent> {
        AsyncStream { continuation in
            let task = Task {
                await consumeEvents(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    vehicleId: vehicleId,
                    session: session,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func consumeEvents(
        baseURL: URL,
        apiKey: String?,
        vehicleId: UUID,
        session: URLSession,
        continuation: AsyncStream<FleetDispatchEvent>.Continuation
    ) async {
        defer { continuation.finish() }

        var normalized = baseURL
        if normalized.path.hasSuffix("/") {
            normalized.deleteLastPathComponent()
        }
        guard let url = URL(string: "v1/vehicles/\(vehicleId.uuidString)/events", relativeTo: normalized) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            for try await line in bytes.lines {
                if Task.isCancelled { return }
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                guard let data = payload.data(using: .utf8) else { continue }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                guard let event = try? decoder.decode(FleetDispatchEvent.self, from: data) else { continue }
                if event.kind == .heartbeat { continue }
                continuation.yield(event)
            }
        } catch {
            if error is CancellationError { return }
        }
    }
}
