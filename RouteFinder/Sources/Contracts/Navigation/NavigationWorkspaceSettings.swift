import Foundation

/// Persists navigation workspace preferences.
public enum NavigationWorkspaceSettings {
    private static let telemetrySourceModeKey = "RouteFinder.telemetrySourceMode"
    private static let autoOptimizeOnRouteFindKey = "RouteFinder.autoOptimizeOnRouteFind"
    private static let voiceGuidanceEnabledKey = "RouteFinder.voiceGuidanceEnabled"
    private static let hosAdvisoryClockEnabledKey = "RouteFinder.hosAdvisoryClockEnabled"
    private static let applyTrafficToSimulationKey = "RouteFinder.applyTrafficToSimulation"
    private static let avoidTrafficDelaysWhenRoutingKey = "RouteFinder.avoidTrafficDelaysWhenRouting"
    private static let breakNowQuickActionEnabledKey = "RouteFinder.breakNowQuickActionEnabled"
    private static let productOnboardingSeenKey = "RouteFinder.productOnboardingSeen"
    private static let routingLiabilityAcceptedKey = "RouteFinder.routingLiabilityAccepted"

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

    /// Whether live traffic congestion caps simulation cruise speed (default off).
    public static func loadApplyTrafficToSimulation(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: applyTrafficToSimulationKey)
    }

    /// Persists whether traffic congestion affects simulation cruise speed.
    public static func saveApplyTrafficToSimulation(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: applyTrafficToSimulationKey)
    }

    /// Whether live traffic jams should trigger avoid-polygon reroute evaluation (default on).
    public static func loadAvoidTrafficDelaysWhenRouting(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: avoidTrafficDelaysWhenRoutingKey) == nil {
            return true
        }
        return defaults.bool(forKey: avoidTrafficDelaysWhenRoutingKey)
    }

    /// Persists whether traffic reroute evaluation runs after route find.
    public static func saveAvoidTrafficDelaysWhenRouting(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: avoidTrafficDelaysWhenRoutingKey)
    }

    /// Whether the Break Now layby quick action is shown (default on, mirroring CoPilot 11.3).
    public static func loadBreakNowQuickActionEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: breakNowQuickActionEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: breakNowQuickActionEnabledKey)
    }

    /// Persists Break Now quick action preference.
    public static func saveBreakNowQuickActionEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: breakNowQuickActionEnabledKey)
    }

    /// Whether the driver has dismissed the product onboarding sheet.
    public static func loadHasSeenProductOnboarding(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: productOnboardingSeenKey)
    }

    /// Persists that the driver has seen and dismissed product onboarding.
    public static func saveHasSeenProductOnboarding(_ seen: Bool, defaults: UserDefaults = .standard) {
        defaults.set(seen, forKey: productOnboardingSeenKey)
    }

    /// Whether the driver accepted the routing liability disclaimer.
    public static func loadHasAcceptedRoutingLiability(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: routingLiabilityAcceptedKey)
    }

    /// Persists acceptance of the routing liability disclaimer.
    public static func saveHasAcceptedRoutingLiability(_ accepted: Bool, defaults: UserDefaults = .standard) {
        defaults.set(accepted, forKey: routingLiabilityAcceptedKey)
    }
}
