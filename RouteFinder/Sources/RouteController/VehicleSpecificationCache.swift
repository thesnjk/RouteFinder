import DataLayer
import Foundation

/// Thread-safe dual-layer cache for verified vehicle registration lookup results.
///
/// Maintains an in-memory dictionary backed by JSON files on disk. Only profiles
/// with ``RegistrySource/verifiedAPI`` are persisted; heuristic fallbacks are rejected.
public actor VehicleSpecificationCache {
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var memoryCache: [String: CachedVehicleProfile] = [:]

    /// Creates a vehicle specification cache in the given directory.
    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("RouteFinder/vehicle-specs", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns a cached profile when present and within the 30-day TTL window.
    public func profile(forKey key: String) -> VehicleSpecificationProfile? {
        let cleanKey = RegistrationNormalizer.normalize(key)

        if let entry = memoryCache[cleanKey] {
            if entry.isExpired {
                memoryCache.removeValue(forKey: cleanKey)
                try? FileManager.default.removeItem(at: cacheURL(forKey: cleanKey))
            } else {
                return entry.profile
            }
        }

        let url = cacheURL(forKey: cleanKey)
        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            let entry = try decoder.decode(CachedVehicleProfile.self, from: data)
            if entry.isExpired {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            memoryCache[cleanKey] = entry
            return entry.profile
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "VehicleSpecificationCache read \(url.lastPathComponent)"
            )
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Stores a verified API profile in memory and on disk.
    public func store(_ profile: VehicleSpecificationProfile, forKey key: String) {
        let cleanKey = RegistrationNormalizer.normalize(key)
        guard profile.source == .verifiedAPI else { return }

        let entry = CachedVehicleProfile(profile: profile, cachedAt: Date())
        memoryCache[cleanKey] = entry
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: cacheURL(forKey: cleanKey), options: .atomic)
    }

    /// Clears all cached vehicle specification entries from memory and disk.
    public func clear() throws {
        memoryCache.removeAll()
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Builds a stable cache key from a registration mark.
    public static func cacheKey(for registrationMark: String) -> String {
        RegistrationNormalizer.normalize(registrationMark)
    }

    private func cacheURL(forKey key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }
}
