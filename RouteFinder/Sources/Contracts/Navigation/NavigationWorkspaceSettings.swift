import Foundation

/// Persists navigation workspace preferences.
public enum NavigationWorkspaceSettings {
    private static let telemetrySourceModeKey = "RouteFinder.telemetrySourceMode"
    private static let autoOptimizeOnRouteFindKey = "RouteFinder.autoOptimizeOnRouteFind"
    private static let voiceGuidanceEnabledKey = "RouteFinder.voiceGuidanceEnabled"
    private static let hosAdvisoryClockEnabledKey = "RouteFinder.hosAdvisoryClockEnabled"

    /// Loads the preferred telemetry source mode.
    public static func loadTelemetrySourceMode(defaults: UserDefaults = .standard) -> LocationProviderMode {
        guard let raw = defaults.string(forKey: telemetrySourceModeKey),
              let mode = LocationProviderMode(rawValue: raw) else {
            return .simulation
        }
        return mode
    }

    /// Persists the preferred telemetry source mode.
    public static func saveTelemetrySourceMode(_ mode: LocationProviderMode, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: telemetrySourceModeKey)
    }

    /// Whether route find should auto-optimize multi-stop sequences.
    public static func loadAutoOptimizeOnRouteFind(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: autoOptimizeOnRouteFindKey)
    }

    /// Persists auto-optimize preference.
    public static func saveAutoOptimizeOnRouteFind(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: autoOptimizeOnRouteFindKey)
    }

    /// Whether voice guidance is enabled.
    public static func loadVoiceGuidanceEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: voiceGuidanceEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: voiceGuidanceEnabledKey)
    }

    /// Persists voice guidance preference.
    public static func saveVoiceGuidanceEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: voiceGuidanceEnabledKey)
    }

    /// Whether the advisory EU hours-of-service clock is enabled.
    public static func loadHosAdvisoryClockEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: hosAdvisoryClockEnabledKey) == nil {
            return false
        }
        return defaults.bool(forKey: hosAdvisoryClockEnabledKey)
    }

    /// Persists advisory HOS clock preference.
    public static func saveHosAdvisoryClockEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: hosAdvisoryClockEnabledKey)
    }
}
