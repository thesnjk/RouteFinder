import Foundation

/// A cached vehicle specification keyed by registration plate for quick re-apply.
public struct VehiclePlateLibraryEntry: Codable, Sendable, Equatable, Identifiable {
    /// Stable identity matching the normalized registration mark.
    public var id: String { registrationKey }
    /// Verified or resolved specification payload.
    public let specification: VehicleSpecificationProfile
    /// Human-formatted registration for UI display.
    public let displayRegistration: String
    /// Optional driver-assigned nickname.
    public var customName: String?
    /// When the entry was last upserted.
    public let savedAt: Date

    /// Normalized registration key used for persistence lookups.
    public var registrationKey: String {
        RegistrationNormalizer.normalize(displayRegistration)
    }

    /// Creates a plate library entry.
    public init(
        specification: VehicleSpecificationProfile,
        displayRegistration: String,
        customName: String? = nil,
        savedAt: Date = Date()
    ) {
        self.specification = specification
        self.displayRegistration = displayRegistration
        self.customName = customName
        self.savedAt = savedAt
    }
}

/// Persists registration → specification entries for the vehicle profile library.
public actor VehiclePlateLibraryStore {
    private let fileURL: URL
    private var cache: [VehiclePlateLibraryEntry]?

    /// Creates a plate library store under Application Support.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let directory = support.appendingPathComponent("RouteFinder", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.fileURL = directory.appendingPathComponent("vehicle-plate-library.json")
        }
    }

    /// Returns all cached entries newest-first.
    public func allEntries() -> [VehiclePlateLibraryEntry] {
        loadIfNeeded()
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Returns a cached entry for the given registration, if present.
    public func entry(forRegistration registration: String) -> VehiclePlateLibraryEntry? {
        let key = RegistrationNormalizer.normalize(registration)
        guard !key.isEmpty else { return nil }
        return loadIfNeeded().first { $0.registrationKey == key }
    }

    /// Inserts or replaces an entry for the registration.
    public func upsert(_ entry: VehiclePlateLibraryEntry) throws {
        let key = entry.registrationKey
        guard !key.isEmpty else { return }
        var entries = loadIfNeeded().filter { $0.registrationKey != key }
        entries.append(entry)
        try persist(entries)
    }

    /// Renames (or clears) the custom display name for a registration.
    public func rename(registration: String, customName: String?) throws {
        let key = RegistrationNormalizer.normalize(registration)
        guard !key.isEmpty else { return }
        var entries = loadIfNeeded()
        guard let index = entries.firstIndex(where: { $0.registrationKey == key }) else { return }
        let existing = entries[index]
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index] = VehiclePlateLibraryEntry(
            specification: existing.specification,
            displayRegistration: existing.displayRegistration,
            customName: (trimmed?.isEmpty == false) ? trimmed : nil,
            savedAt: existing.savedAt
        )
        try persist(entries)
    }

    /// Deletes a cached entry by registration.
    public func delete(registration: String) throws {
        let key = RegistrationNormalizer.normalize(registration)
        guard !key.isEmpty else { return }
        let entries = loadIfNeeded().filter { $0.registrationKey != key }
        try persist(entries)
    }

    private func loadIfNeeded() -> [VehiclePlateLibraryEntry] {
        if let cache { return cache }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([VehiclePlateLibraryEntry].self, from: data) else {
            cache = []
            return []
        }
        cache = decoded
        return decoded
    }

    private func persist(_ entries: [VehiclePlateLibraryEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: fileURL, options: [.atomic])
        cache = entries
    }
}
