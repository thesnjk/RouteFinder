import Foundation
import Network

/// Minimal localhost HTTP file server for offline MapLibre style / tile packs.
///
/// Serves files from Application Support/RouteFinder/map-pack/ on `127.0.0.1`.
public actor LocalHTTPTileServer {
    private let rootDirectory: URL
    private var listener: NWListener?
    private var port: UInt16?

    /// Creates a server rooted at the given map-pack directory.
    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    /// Bound loopback port once started.
    public func boundPort() -> UInt16? {
        port
    }

    /// Base URL such as `http://127.0.0.1:54321/` when running.
    public func baseURL() -> URL? {
        guard let port else { return nil }
        return URL(string: "http://127.0.0.1:\(port)/")
    }

    /// Starts listening on an ephemeral loopback port.
    public func start() async throws {
        if listener != nil { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: .any)
        listener.newConnectionHandler = { [rootDirectory] connection in
            Self.handle(connection: connection, root: rootDirectory)
        }

        let portBox = PortBox()
        listener.stateUpdateHandler = { state in
            if case .ready = state, let value = listener.port?.rawValue {
                portBox.value = value
            }
        }
        listener.start(queue: .global(qos: .userInitiated))

        // Wait briefly for the listener to bind.
        for _ in 0..<50 {
            if let value = portBox.value {
                self.listener = listener
                self.port = value
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        listener.cancel()
        throw LocalHTTPTileServerError.bindFailed
    }

    /// Stops the listener.
    public func stop() {
        listener?.cancel()
        listener = nil
        port = nil
    }

    private static func handle(connection: NWConnection, root: URL) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, error in
            defer { connection.cancel() }
            guard error == nil, let data, let request = String(data: data, encoding: .utf8) else {
                return
            }
            let response = respond(to: request, root: root)
            connection.send(content: response, completion: .contentProcessed { _ in })
        }
    }

    private static func respond(to request: String, root: URL) -> Data {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return httpResponse(status: 405, body: Data("Method Not Allowed".utf8), contentType: "text/plain")
        }

        var path = String(parts[1])
        if let q = path.firstIndex(of: "?") {
            path = String(path[..<q])
        }
        path = path.removingPercentEncoding ?? path
        if path == "/" { path = "/style.json" }

        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let fileURL = root.appendingPathComponent(relative).standardizedFileURL
        let rootStandard = root.standardizedFileURL
        guard fileURL.path.hasPrefix(rootStandard.path) else {
            return httpResponse(status: 403, body: Data("Forbidden".utf8), contentType: "text/plain")
        }
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let body = try? Data(contentsOf: fileURL) else {
            return httpResponse(status: 404, body: Data("Not Found".utf8), contentType: "text/plain")
        }
        return httpResponse(status: 200, body: body, contentType: mimeType(for: fileURL))
    }

    private static func httpResponse(status: Int, body: Data, contentType: String) -> Data {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 403: reason = "Forbidden"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        default: reason = "Error"
        }
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "json": return "application/json"
        case "pbf", "mvt": return "application/vnd.mapbox-vector-tile"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "html": return "text/html; charset=utf-8"
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "pmtiles": return "application/octet-stream"
        default: return "application/octet-stream"
        }
    }
}

/// Errors from ``LocalHTTPTileServer``.
public enum LocalHTTPTileServerError: Error, Sendable, LocalizedError {
    case bindFailed

    public var errorDescription: String? {
        switch self {
        case .bindFailed:
            return "Failed to bind local map tile server on 127.0.0.1."
        }
    }
}

/// Thread-safe box for NWListener port discovery.
private final class PortBox: @unchecked Sendable {
    var value: UInt16?
}
