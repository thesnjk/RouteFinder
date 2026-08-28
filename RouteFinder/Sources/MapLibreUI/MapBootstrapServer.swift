import Foundation

#if os(iOS)
/// Serves bundled MapLibre bootstrap HTML on loopback HTTP so WKWebView can load HTTPS map styles.
public actor MapBootstrapServer {
    public static let shared = MapBootstrapServer()

    private static let serveDirectoryName = "RouteFinderMapBootstrap"
    private static let mapHTMLFileName = "map.html"

    private var server: LocalHTTPTileServer?
    private var serveRoot: URL?

    private init() {}

    /// Writes HTML and bundled assets, starts the server if needed, and returns the map page URL.
    public func mapPageURL(html: String) async throws -> URL {
        let root = try prepareServeRoot(html: html)
        if server == nil || serveRoot?.path != root.path {
            await server?.stop()
            let tileServer = LocalHTTPTileServer(rootDirectory: root)
            try await tileServer.start()
            server = tileServer
            serveRoot = root
        } else {
            try html.write(
                to: root.appendingPathComponent(Self.mapHTMLFileName),
                atomically: true,
                encoding: .utf8
            )
        }
        guard let baseURL = await server?.baseURL() else {
            throw MapBootstrapServerError.serverUnavailable
        }
        return baseURL.appendingPathComponent(Self.mapHTMLFileName)
    }

    private func prepareServeRoot(html: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.serveDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try html.write(
            to: root.appendingPathComponent(Self.mapHTMLFileName),
            atomically: true,
            encoding: .utf8
        )
        try copyBundledAsset(named: "maplibre-gl", extension: "js", into: root)
        try copyBundledAsset(named: "maplibre-gl", extension: "css", into: root)
        return root
    }

    private func copyBundledAsset(named name: String, extension ext: String, into root: URL) throws {
        guard let source = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        let destination = root.appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

/// Errors from ``MapBootstrapServer``.
public enum MapBootstrapServerError: Error, Sendable, LocalizedError {
    case serverUnavailable

    public var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return "Local map bootstrap server is unavailable."
        }
    }
}
#endif
