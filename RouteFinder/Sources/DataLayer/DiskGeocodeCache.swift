import Contracts
import Foundation

/// Simple last-N disk cache for successful Pelias / OpenRouteService geocode hits.
///
/// Entries are stored newest-first under Application Support and reused when the network
/// is unavailable or the API key is missing.
public actor DiskGeocodeCache {
    /// Default number of recent hits retained on disk.
    public static let defaultCapacity = 64

    private let cacheDirectory: URL
    private let indexURL: URL
    private let capacity: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var entries: [Entry] = []

    /// Creates a last-N geocode hit cache.
    public init(cacheDirectory: URL? = nil, capacity: Int = DiskGeocodeCache.defaultCapacity) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.cacheDirectory = support.appendingPathComponent("RouteFinder/geocode-hits", isDirectory: true)
        }
        self.capacity = max(1, capacity)
        self.indexURL = self.cacheDirectory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        self.entries = Self.loadIndex(from: indexURL, decoder: decoder)
    }

    /// Records a successful geocode response for later offline reuse.
    public func store(query: String, suggestions: [GeocodeSuggestion]) {
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty, !suggestions.isEmpty else { return }
        entries.removeAll { $0.normalizedQuery == normalized }
        entries.insert(
            Entry(normalizedQuery: normalized, displayQuery: query, suggestions: suggestions, storedAt: Date()),
            at: 0
        )
        if entries.count > capacity {
            entries = Array(entries.prefix(capacity))
        }
        persist()
    }

    /// Returns cached suggestions for an exact (case-insensitive) query match.
    public func suggestions(matching query: String) -> [GeocodeSuggestion]? {
        let normalized = Self.normalize(query)
        guard let entry = entries.first(where: { $0.normalizedQuery == normalized }) else {
            return nil
        }
        return entry.suggestions
    }

    /// Prefix search over recent hit display queries (newest first).
    public func suggestions(prefix query: String, limit: Int = 8) -> [GeocodeSuggestion] {
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty else { return [] }
        var results: [GeocodeSuggestion] = []
        var seen: Set<String> = []
        for entry in entries where entry.normalizedQuery.hasPrefix(normalized) {
            for suggestion in entry.suggestions {
                if seen.insert(suggestion.id).inserted {
                    results.append(suggestion)
                    if results.count >= limit { return results }
                }
            }
        }
        return results
    }

    /// Number of retained hit entries.
    public func count() -> Int {
        entries.count
    }

    /// Clears all cached hits.
    public func clear() throws {
        entries = []
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func persist() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private static func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func loadIndex(from url: URL, decoder: JSONDecoder) -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([Entry].self, from: data)) ?? []
    }

    private struct Entry: Codable, Sendable {
        let normalizedQuery: String
        let displayQuery: String
        let suggestions: [GeocodeSuggestion]
        let storedAt: Date
    }
}
