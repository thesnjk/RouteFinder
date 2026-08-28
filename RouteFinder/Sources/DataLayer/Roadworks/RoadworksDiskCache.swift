import Contracts
import Foundation

/// Disk-backed cache for roadworks corridor queries.
public actor RoadworksDiskCache {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a roadworks disk cache.
    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RouteFinder/roadworks", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Loads cached roadworks for a corridor key.
    public func load(key: String) -> [RoadworkSite]? {
        let url = cacheURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CacheEntry.self, from: data).sites
    }

    /// Stores roadworks for a corridor key.
    public func store(_ sites: [RoadworkSite], forKey key: String) {
        let entry = CacheEntry(sites: sites, storedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: cacheURL(forKey: key), options: .atomic)
    }

    private func cacheURL(forKey key: String) -> URL {
        let safe = key
            .data(using: .utf8)?
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            ?? key
        return cacheDirectory.appendingPathComponent("\(safe).json")
    }

    private struct CacheEntry: Codable {
        let sites: [RoadworkSite]
        let storedAt: Date
    }
}
