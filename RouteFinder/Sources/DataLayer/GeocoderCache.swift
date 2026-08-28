import Contracts
import Foundation

/// Disk-backed cache for Nominatim geocode results (usage-policy friendly).
public actor GeocoderCache {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a geocoder cache in the given directory.
    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RouteFinder/geocoder", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Reads cached suggestions for a query near a viewport center.
    public func suggestions(forKey key: String) -> [GeocodeSuggestion]? {
        let url = cacheURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            let entry = try decoder.decode(CacheEntry.self, from: data)
            return entry.suggestions
        } catch {
            DecodingDiagnostics.logDecodingError(error, context: "GeocoderCache read \(url.lastPathComponent)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Stores suggestions for a query key.
    public func store(_ suggestions: [GeocodeSuggestion], forKey key: String) {
        let entry = CacheEntry(suggestions: suggestions, storedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: cacheURL(forKey: key), options: .atomic)
    }

    /// Clears all cached geocode entries.
    public func clear() throws {
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Builds a stable cache key from query and viewport for biased search.
    public static func cacheKey(query: String, near center: Coordinate, language: String? = nil) -> String {
        let normalized = query.trimmingCharacters(in: .whitespaces).lowercased()
        let lat = String(format: "%.2f", center.latitude)
        let lon = String(format: "%.2f", center.longitude)
        let lang = language?.lowercased() ?? "default"
        let raw = "biased|\(normalized)|\(lat)|\(lon)|\(lang)"
        return raw.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? normalized
    }

    /// Builds a stable cache key for global search with viewport focus.
    public static func cacheKeyGlobal(query: String, near center: Coordinate, language: String? = nil) -> String {
        let normalized = query.trimmingCharacters(in: .whitespaces).lowercased()
        let lat = String(format: "%.2f", center.latitude)
        let lon = String(format: "%.2f", center.longitude)
        let lang = language?.lowercased() ?? "default"
        let raw = "global|\(normalized)|\(lat)|\(lon)|\(lang)"
        return raw.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_") ?? normalized
    }

    /// Builds a stable cache key for global (viewport-independent) search.
    public static func cacheKeyGlobal(query: String) -> String {
        cacheKeyGlobal(query: query, near: Coordinate(latitude: 0, longitude: 0))
    }

    private func cacheURL(forKey key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }

    private struct CacheEntry: Codable {
        let suggestions: [GeocodeSuggestion]
        let storedAt: Date
    }
}
