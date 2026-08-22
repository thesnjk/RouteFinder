import Contracts
import Foundation

/// Persists named vehicle profiles in UserDefaults.
public actor VehicleProfileStore {
    private let defaults: UserDefaults
    private let storageKey = "RouteFinder.savedVehicleProfiles"

    /// Creates a profile store backed by the given user defaults suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns all saved profiles ordered by name.
    public func loadProfiles() -> [VehicleProfile] {
        guard let data = defaults.data(forKey: storageKey),
              let profiles = try? JSONDecoder().decode([VehicleProfile].self, from: data) else {
            return []
        }
        return profiles.sorted {
            ($0.savedProfileName ?? "") < ($1.savedProfileName ?? "")
        }
    }

    /// Saves or replaces a profile keyed by its saved name.
    public func save(_ profile: VehicleProfile) throws {
        guard let name = profile.savedProfileName, !name.isEmpty else {
            throw VehicleProfileStoreError.missingName
        }
        var profiles = loadProfiles().filter { $0.savedProfileName != name }
        profiles.append(profile)
        try persist(profiles)
    }

    /// Deletes a profile by name.
    public func delete(named name: String) throws {
        let profiles = loadProfiles().filter { $0.savedProfileName != name }
        try persist(profiles)
    }

    /// Built-in presets not yet saved by the user.
    public func presetProfiles() -> [VehicleProfile] {
        [.ukArtic, .ukRigid26t]
    }

    private func persist(_ profiles: [VehicleProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        defaults.set(data, forKey: storageKey)
    }

    private static let orsAPIKeyKey = "RouteFinder.orsAPIKey"
    private static let dvlaAPIKeyKey = "RouteFinder.dvlaAPIKey"
    private static let regCheckUsernameKey = "RouteFinder.regCheckUsername"
    private static let tomTomAPIKeyKey = "RouteFinder.tomTomAPIKey"
    private static let openWeatherAPIKeyKey = "RouteFinder.openWeatherAPIKey"

    /// Loads the persisted HeiGIT OpenRouteService API key, if any.
    public static func loadORSAPIKey(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: orsAPIKeyKey)
    }

    /// Persists the HeiGIT OpenRouteService API key.
    public static func saveORSAPIKey(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: orsAPIKeyKey)
    }

    /// Loads the persisted DVLA Vehicle Enquiry Service API key, if any.
    public static func loadDVLAAPIKey(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: dvlaAPIKeyKey)
    }

    /// Persists the DVLA Vehicle Enquiry Service API key.
    public static func saveDVLAAPIKey(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: dvlaAPIKeyKey)
    }

    /// Loads the persisted RegCheck account username, if any.
    public static func loadRegCheckUsername(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: regCheckUsernameKey)
    }

    /// Persists the RegCheck account username.
    public static func saveRegCheckUsername(_ username: String, defaults: UserDefaults = .standard) {
        defaults.set(username, forKey: regCheckUsernameKey)
    }

    /// Loads the persisted TomTom Traffic Flow API key, if any.
    public static func loadTomTomAPIKey(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: tomTomAPIKeyKey)
    }

    /// Persists the TomTom Traffic Flow API key.
    public static func saveTomTomAPIKey(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: tomTomAPIKeyKey)
    }

    /// Loads the persisted OpenWeather API key, if any.
    public static func loadOpenWeatherAPIKey(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: openWeatherAPIKeyKey)
    }

    /// Persists the OpenWeather API key.
    public static func saveOpenWeatherAPIKey(_ key: String, defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: openWeatherAPIKeyKey)
    }
}

/// Errors when persisting vehicle profiles.
public enum VehicleProfileStoreError: Error, Sendable, LocalizedError {
    case missingName

    public var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a profile name before saving."
        }
    }
}
