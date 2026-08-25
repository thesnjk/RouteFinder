import Contracts
import Foundation

/// Disk-backed cache for truck POI corridor queries.
public actor TruckPoiDiskCache {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RouteFinder/truck_poi", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    public func load(key: String) -> [TruckPoi]? {
        let url = cacheURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CacheEntry.self, from: data).pois
    }

    public func store(_ pois: [TruckPoi], forKey key: String) {
        let entry = CacheEntry(pois: pois, storedAt: Date())
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
        let pois: [TruckPoi]
        let storedAt: Date
    }
}
