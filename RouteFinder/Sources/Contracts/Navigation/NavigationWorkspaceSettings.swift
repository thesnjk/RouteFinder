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
    private static let laybyVoiceAlertsEnabledKey = "RouteFinder.laybyVoiceAlertsEnabled"
    private static let laybyAlertDistanceMetersKey = "RouteFinder.laybyAlertDistanceMeters"
    private static let fuelCardProviderKey = "RouteFinder.fuelCardProvider"
    private static let hazardVoiceAlertsEnabledKey = "RouteFinder.hazardVoiceAlertsEnabled"
    private static let hazardAlertDistanceMetersKey = "RouteFinder.hazardAlertDistanceMeters"
    private static let speechVoiceIdentifierKey = "RouteFinder.speechVoiceIdentifier"
    private static let speechRateKey = "RouteFinder.speechRate"
    private static let vehicleModeOnboardingCompletedKey = "RouteFinder.vehicleModeOnboardingCompleted"
    private static let roleSelectionCompletedKey = "RouteFinder.roleSelectionCompleted"
    private static let launchRoleKey = "RouteFinder.launchRole"
    private static let roleFollowUpCompletedKey = "RouteFinder.roleFollowUpCompleted"

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

    /// Whether spoken layby-ahead alerts are enabled (default on).
    public static func loadLaybyVoiceAlertsEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: laybyVoiceAlertsEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: laybyVoiceAlertsEnabledKey)
    }

    /// Persists spoken layby-ahead alert preference.
    public static func saveLaybyVoiceAlertsEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: laybyVoiceAlertsEnabledKey)
    }

    /// Distance inside which a layby is announced once (default 5000 m).
    public static func loadLaybyAlertDistanceMeters(defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.double(forKey: laybyAlertDistanceMetersKey)
        return stored > 0 ? stored : LaybyAlertFormatter.defaultAlertDistanceMeters
    }

    /// Persists layby announce distance threshold in meters.
    public static func saveLaybyAlertDistanceMeters(_ meters: Double, defaults: UserDefaults = .standard) {
        defaults.set(max(500, meters), forKey: laybyAlertDistanceMetersKey)
    }

    /// Selected fleet fuel card provider for ahead-of-route matching (default none).
    public static func loadFuelCardProvider(defaults: UserDefaults = .standard) -> FuelCardProvider {
        guard let raw = defaults.string(forKey: fuelCardProviderKey),
              let provider = FuelCardProvider(rawValue: raw) else {
            return .none
        }
        return provider
    }

    /// Persists fleet fuel card provider preference.
    public static func saveFuelCardProvider(_ provider: FuelCardProvider, defaults: UserDefaults = .standard) {
        defaults.set(provider.rawValue, forKey: fuelCardProviderKey)
    }

    /// Whether spoken closure/traffic hazard alerts are enabled (default on).
    public static func loadHazardVoiceAlertsEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: hazardVoiceAlertsEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: hazardVoiceAlertsEnabledKey)
    }

    /// Persists spoken hazard-ahead alert preference.
    public static func saveHazardVoiceAlertsEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: hazardVoiceAlertsEnabledKey)
    }

    /// Distance inside which a hazard is announced once (default 3000 m).
    public static func loadHazardAlertDistanceMeters(defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.double(forKey: hazardAlertDistanceMetersKey)
        return stored > 0 ? stored : HazardAheadFormatter.defaultAlertDistanceMeters
    }

    /// Persists hazard announce distance threshold in meters.
    public static func saveHazardAlertDistanceMeters(_ meters: Double, defaults: UserDefaults = .standard) {
        defaults.set(max(300, meters), forKey: hazardAlertDistanceMetersKey)
    }

    /// Selected AVSpeechSynthesisVoice identifier for navigation prompts.
    public static func loadSpeechVoiceIdentifier(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: speechVoiceIdentifierKey)
    }

    /// Persists the selected speech voice identifier.
    public static func saveSpeechVoiceIdentifier(_ identifier: String?, defaults: UserDefaults = .standard) {
        if let identifier {
            defaults.set(identifier, forKey: speechVoiceIdentifierKey)
        } else {
            defaults.removeObject(forKey: speechVoiceIdentifierKey)
        }
    }

    /// Speech rate for navigation prompts (AVSpeechUtterance rate scale, default ~0.5).
    public static func loadSpeechRate(defaults: UserDefaults = .standard) -> Float {
        if defaults.object(forKey: speechRateKey) == nil {
            return 0.5
        }
        return defaults.float(forKey: speechRateKey)
    }

    /// Persists speech rate for navigation prompts.
    public static func saveSpeechRate(_ rate: Float, defaults: UserDefaults = .standard) {
        defaults.set(min(max(rate, 0.35), 0.65), forKey: speechRateKey)
    }

    /// Whether the driver completed the Car vs HGV onboarding pick.
    public static func loadHasCompletedVehicleModeOnboarding(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: vehicleModeOnboardingCompletedKey)
    }

    /// Persists completion of the Car vs HGV onboarding pick.
    public static func saveHasCompletedVehicleModeOnboarding(_ completed: Bool, defaults: UserDefaults = .standard) {
        defaults.set(completed, forKey: vehicleModeOnboardingCompletedKey)
    }

    /// Whether the user completed the first-launch role picker.
    public static func loadHasCompletedRoleSelection(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: roleSelectionCompletedKey)
    }

    /// Persists completion of the first-launch role picker.
    public static func saveHasCompletedRoleSelection(_ completed: Bool, defaults: UserDefaults = .standard) {
        defaults.set(completed, forKey: roleSelectionCompletedKey)
    }

    /// Loads the selected launch role, if any.
    public static func loadLaunchRole(defaults: UserDefaults = .standard) -> LaunchRole? {
        guard let raw = defaults.string(forKey: launchRoleKey) else { return nil }
        return LaunchRole(rawValue: raw)
    }

    /// Persists the selected launch role.
    public static func saveLaunchRole(_ role: LaunchRole, defaults: UserDefaults = .standard) {
        defaults.set(role.rawValue, forKey: launchRoleKey)
    }

    /// Whether the role-specific follow-up sheet (fleet CTA / dispatcher guide / office PC) was dismissed.
    public static func loadHasCompletedRoleFollowUp(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: roleFollowUpCompletedKey)
    }

    /// Persists completion of the role-specific follow-up sheet.
    public static func saveHasCompletedRoleFollowUp(_ completed: Bool, defaults: UserDefaults = .standard) {
        defaults.set(completed, forKey: roleFollowUpCompletedKey)
    }
}
