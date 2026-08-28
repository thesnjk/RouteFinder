import Foundation

/// Discovers and registers a local MapLibre style / tile pack for offline rendering.
public actor OfflineMapPackStore {
    /// Status snapshot for Settings UI.
    public struct Status: Sendable, Hashable {
        /// Whether `style.json` exists in the pack directory.
        public let packPresent: Bool
        /// Absolute path to the pack root.
        public let packDirectoryPath: String
        /// Local HTTP style URL when the server is running.
        public let localStyleURL: URL?
        /// Human-readable summary.
        public let message: String

        public init(packPresent: Bool, packDirectoryPath: String, localStyleURL: URL?, message: String) {
            self.packPresent = packPresent
            self.packDirectoryPath = packDirectoryPath
            self.localStyleURL = localStyleURL
            self.message = message
        }
    }

    private let packDirectory: URL
    private var server: LocalHTTPTileServer?
    private var registeredStyleURL: URL?
    private var registeredPMTilesPath: URL?

    /// Creates a pack store rooted at Application Support/RouteFinder/map-pack/.
    public init(packDirectory: URL? = nil) {
        if let packDirectory {
            self.packDirectory = packDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.packDirectory = support.appendingPathComponent("RouteFinder/map-pack", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.packDirectory, withIntermediateDirectories: true)
    }

    /// Default pack directory path.
    public static func defaultPackDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("RouteFinder/map-pack", isDirectory: true)
    }

    /// Whether `style.json` is present on disk.
    public func isPackPresent() -> Bool {
        FileManager.default.fileExists(atPath: styleFileURL.path)
    }

    /// Registers a local style file URL (file:// or http://127.0.0.1).
    public func registerLocalStyle(url: URL) {
        registeredStyleURL = url
    }

    /// Registers an optional PMTiles path for documentation / future handlers.
    public func registerPMTiles(path: URL) {
        registeredPMTilesPath = path
    }

    /// Ensures the localhost tile server is running when a pack is present.
    ///
    /// - Returns: Style URL suitable for MapLibre `map.setStyle(...)`, or `nil` to keep CDN style.
    @discardableResult
    public func prepareLocalStyleIfAvailable(enabled: Bool) async throws -> URL? {
        guard enabled else {
            await stopServer()
            return nil
        }
        guard isPackPresent() else {
            await stopServer()
            return registeredStyleURL
        }
        guard isValidStyleFile(at: styleFileURL) else {
            await stopServer()
            return nil
        }

        if server == nil {
            let tileServer = LocalHTTPTileServer(rootDirectory: packDirectory)
            try await tileServer.start()
            server = tileServer
        }
        guard let base = await server?.baseURL() else {
            return nil
        }
        let styleURL = base.appendingPathComponent("style.json")
        registeredStyleURL = styleURL
        return styleURL
    }

    /// Current pack / server status for Settings.
    public func status(useLocalWhenPresent: Bool) async -> Status {
        let present = isPackPresent()
        let style = await server?.baseURL()?.appendingPathComponent("style.json") ?? registeredStyleURL
        let message: String
        if !present {
            message = "No pack — place style.json under Application Support/RouteFinder/map-pack/"
        } else if !useLocalWhenPresent {
            message = "Pack found — enable “Use local map style” to activate"
        } else if let style {
            message = "Serving \(style.absoluteString)"
        } else {
            message = "Pack found — start map to serve locally"
        }
        return Status(
            packPresent: present,
            packDirectoryPath: packDirectory.path,
            localStyleURL: style,
            message: message
        )
    }

    /// Stops the local HTTP server if running.
    public func stopServer() async {
        await server?.stop()
        server = nil
    }

    /// `routefinder-tiles://style.json` form for a future WKURLSchemeHandler.
    public func customSchemeStyleURL() -> URL {
        URL(string: "\(MapLibreConfiguration.localTilesURLScheme)://style.json")!
    }

    private var styleFileURL: URL {
        packDirectory.appendingPathComponent("style.json")
    }

    private func isValidStyleFile(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return json["version"] != nil
    }
}
