import Contracts
import Foundation
import GraphCore

/// Errors raised while loading or downloading offline graph tiles.
public enum OfflineGraphStoreError: Error, Sendable, LocalizedError {
    case noTilesAvailable
    case downloadFailed(cell: String, status: Int)
    case decodeFailed(cell: String, underlying: Error)
    case invalidTileServerURL

    /// Shared actionable copy when neither ORS nor offline tiles can route.
    public static let missingBackendUserMessage =
        "No offline map tiles and no OpenRouteService key. Add an ORS key in Settings, or install *.graphjson under Application Support/RouteFinder/tiles/."

    public var errorDescription: String? {
        switch self {
        case .noTilesAvailable:
            return Self.missingBackendUserMessage
        case .downloadFailed(let cell, let status):
            return "Failed to download tile \(cell) (HTTP \(status))."
        case .decodeFailed(let cell, _):
            return "Failed to decode graph tile \(cell)."
        case .invalidTileServerURL:
            return "Tile server URL is invalid."
        }
    }
}

/// Disk-backed offline routing graph store conforming to ``OfflineGraphStorePort``.
///
/// Loads `*.graphjson` tiles covering a bounding box from a local Application Support
/// directory and optionally downloads missing tiles from a configurable HTTPS base URL.
public actor DiskOfflineGraphStore: OfflineGraphStorePort {
    /// Approximate UK mainland bbox (full download is large — prefer demo corridor for MVP).
    public static let ukBoundingBox = (
        minLat: 49.8,
        maxLat: 58.7,
        minLon: -8.2,
        maxLon: 1.8
    )

    /// Smaller Norfolk demo corridor matching synthetic test graphs (~52.6, 1.3).
    public static let demoCorridorBoundingBox = (
        minLat: 52.55,
        maxLat: 52.70,
        minLon: 1.20,
        maxLon: 1.40
    )

    private let tilesDirectory: URL
    private var tileBaseURL: URL?
    private let session: URLSession
    private let resolution: Int
    private let maxSnapDistanceMeters: Double
    private var tiledGraph: TiledGraph?
    private var loadedCells: Set<H3CellIndex> = []

    /// Creates an offline graph store.
    ///
    /// - Parameters:
    ///   - tilesDirectory: Local tile cache (defaults to Application Support/RouteFinder/tiles/).
    ///   - tileBaseURL: Optional HTTPS CDN base whose objects are named `<h3hex>.graphjson`.
    ///   - session: URL session used for remote tile downloads.
    ///   - resolution: H3-compatible resolution used when enumerating corridor cells.
    ///   - maxSnapDistanceMeters: Maximum snap distance for ``match(latitude:longitude:)``.
    public init(
        tilesDirectory: URL? = nil,
        tileBaseURL: URL? = nil,
        session: URLSession = SecureURLSession.shared,
        resolution: Int = H3Grid.defaultResolution,
        maxSnapDistanceMeters: Double = MapMatcher.defaultMaxSnapDistanceMeters
    ) {
        if let tilesDirectory {
            self.tilesDirectory = tilesDirectory
        } else {
            self.tilesDirectory = Self.defaultTilesDirectory()
        }
        self.tileBaseURL = tileBaseURL
        self.session = session
        self.resolution = resolution
        self.maxSnapDistanceMeters = maxSnapDistanceMeters
        try? FileManager.default.createDirectory(at: self.tilesDirectory, withIntermediateDirectories: true)
    }

    /// Default on-disk tile cache directory.
    public static func defaultTilesDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("RouteFinder/tiles", isDirectory: true)
    }

    /// Updates the remote tile base URL used when local tiles are missing.
    public func setTileBaseURL(_ url: URL?) {
        tileBaseURL = url
    }

    /// The currently assembled tiled graph, if any.
    public func currentGraph() -> TiledGraph? {
        tiledGraph
    }

    /// Number of H3 cells currently held in memory.
    public func loadedTileCount() -> Int {
        loadedCells.count
    }

    /// Whether any `*.graphjson` files exist in the local tiles directory.
    public func hasLocalTiles() -> Bool {
        H3TileIndex(tilesDirectory: tilesDirectory).hasGraphJSONTiles()
    }

    /// Whether a remote tile CDN base URL is configured.
    public func hasTileServerURL() -> Bool {
        tileBaseURL != nil
    }

    /// Offline routing is usable when local tiles exist or a tile server URL is set.
    public func hasOfflineTilesAvailable() -> Bool {
        hasLocalTiles() || hasTileServerURL()
    }

    /// Ensures graph tiles covering the bounding box are on disk and assembled in memory.
    public func ensureCorridor(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double
    ) async throws {
        try await ensureCorridor(
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            onProgress: nil
        )
    }

    /// Ensures graph tiles covering the bounding box are on disk and assembled in memory.
    ///
    /// - Parameter onProgress: Optional callback with completed/total cell count after each cell.
    public func ensureCorridor(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws {
        let cells = H3Grid.cellsCovering(
            minLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            resolution: resolution
        )
        let index = H3TileIndex(tilesDirectory: tilesDirectory)
        var tiles: [GraphTile] = []
        let decoder = JSONDecoder()
        let total = cells.count
        var completed = 0

        for cell in cells {
            let localURL = index.tileURL(for: cell)
            if !FileManager.default.fileExists(atPath: localURL.path) {
                try await downloadTileIfNeeded(cell: cell, destination: localURL)
            }
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                completed += 1
                onProgress?(completed, total)
                continue
            }
            do {
                let data = try Data(contentsOf: localURL)
                let tile = try decoder.decode(GraphTile.self, from: data)
                tiles.append(tile)
                loadedCells.insert(cell)
            } catch {
                throw OfflineGraphStoreError.decodeFailed(cell: cell.description, underlying: error)
            }
            completed += 1
            onProgress?(completed, total)
        }

        guard !tiles.isEmpty else {
            throw OfflineGraphStoreError.noTilesAvailable
        }

        // Merge newly loaded corridor tiles with any previously loaded cells still on disk.
        if !loadedCells.isEmpty {
            var merged: [GraphTile] = tiles
            var seen = Set(tiles.map(\.h3Index))
            for cell in loadedCells where !seen.contains(cell) {
                let url = index.tileURL(for: cell)
                guard FileManager.default.fileExists(atPath: url.path),
                      let data = try? Data(contentsOf: url),
                      let tile = try? decoder.decode(GraphTile.self, from: data) else {
                    continue
                }
                merged.append(tile)
                seen.insert(cell)
            }
            tiledGraph = TiledGraph(tiles: merged)
        } else {
            tiledGraph = TiledGraph(tiles: tiles)
        }
    }

    /// Loads every `*.graphjson` already present in the tiles directory (no network).
    public func loadLocalTiles() throws {
        let index = H3TileIndex(tilesDirectory: tilesDirectory)
        let urls = index.allTileURLs()
        guard !urls.isEmpty else {
            throw OfflineGraphStoreError.noTilesAvailable
        }
        let decoder = JSONDecoder()
        var tiles: [GraphTile] = []
        var cells: Set<H3CellIndex> = []
        for url in urls {
            let data = try Data(contentsOf: url)
            let tile = try decoder.decode(GraphTile.self, from: data)
            tiles.append(tile)
            cells.insert(tile.h3Index)
        }
        tiledGraph = TiledGraph(tiles: tiles)
        loadedCells = cells
    }

    /// Snaps a coordinate to the nearest road node in the loaded tiled graph.
    public func match(latitude: Double, longitude: Double) async throws -> String? {
        guard let graph = tiledGraph else {
            throw OfflineGraphStoreError.noTilesAvailable
        }
        let coordinate = Coordinate(latitude: latitude, longitude: longitude)
        if let match = graph.matchToRoad(to: coordinate, maxDistanceMeters: maxSnapDistanceMeters) {
            return match.nodeID
        }
        return graph.findNearestNode(to: coordinate)?.id
    }

    /// Full map-match result including snap distance and road name.
    public func matchDetailed(latitude: Double, longitude: Double) async throws -> MapMatchResult? {
        guard let graph = tiledGraph else {
            throw OfflineGraphStoreError.noTilesAvailable
        }
        let coordinate = Coordinate(latitude: latitude, longitude: longitude)
        if let match = graph.matchToRoad(to: coordinate, maxDistanceMeters: maxSnapDistanceMeters) {
            return match
        }
        guard let node = graph.findNearestNode(to: coordinate) else { return nil }
        let snapped = Coordinate(latitude: node.latitude, longitude: node.longitude)
        let distance = Haversine.distance(from: coordinate, to: snapped)
        guard distance <= maxSnapDistanceMeters else { return nil }
        return MapMatchResult(
            nodeID: node.id,
            snappedCoordinate: snapped,
            snapDistanceMeters: distance,
            roadName: node.name
        )
    }

    private func downloadTileIfNeeded(cell: H3CellIndex, destination: URL) async throws {
        guard let base = tileBaseURL else { return }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw OfflineGraphStoreError.invalidTileServerURL
        }
        let trimmedPath = (components.path as NSString).standardizingPath
        let basePath = trimmedPath.hasSuffix("/") ? trimmedPath : trimmedPath + "/"
        components.path = basePath + "\(cell.description).graphjson"
        guard let remoteURL = components.url else {
            throw OfflineGraphStoreError.invalidTileServerURL
        }

        let request = URLRequest(url: remoteURL)
        guard request.isSecureHTTPS else {
            // Local / non-HTTPS CDN bases are unsupported by SecureURLSession policy.
            return
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OfflineGraphStoreError.downloadFailed(cell: cell.description, status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                return
            }
            throw OfflineGraphStoreError.downloadFailed(cell: cell.description, status: http.statusCode)
        }
        try data.write(to: destination, options: .atomic)
    }
}
