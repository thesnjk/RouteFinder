import Contracts
import Foundation

/// Maps H3 cell indices to on-disk tile file paths.
public struct H3TileIndex: Sendable {
    private let tilesDirectory: URL

    /// Creates a tile index for the given directory.
    public init(tilesDirectory: URL) {
        self.tilesDirectory = tilesDirectory
    }

    /// Returns the file URL for a tile.
    public func tileURL(for cell: H3CellIndex) -> URL {
        tilesDirectory.appendingPathComponent("\(cell.description).graphjson")
    }

    /// Returns all tile files in the directory.
    public func allTileURLs() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: tilesDirectory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "graphjson" } ?? []
    }

    /// Whether any `*.graphjson` tiles exist in the directory.
    public func hasGraphJSONTiles() -> Bool {
        !allTileURLs().isEmpty
    }
}
