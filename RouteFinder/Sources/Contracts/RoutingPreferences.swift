/// Unified bundle of all routing preferences from the UI.
public struct RoutingPreferences: Sendable, Hashable, Codable {
    public let optimizationMode: OptimizationMode
    public let avoidTolls: Bool
    public let avoidFerries: Bool
    public let avoidTunnels: Bool
    public let hurryMode: Bool
    public let isHGVMode: Bool
    public let avoidResidential: Bool
    public let avoidCameras: Bool
    public let avoidHazmatRestricted: Bool
    public let enforceTurnRadius: Bool
    public let enforceCurveSpeed: Bool
    public let vehicle: VehicleProfile
    public let algorithm: RoutingAlgorithm
    /// When true, ORS requests include `extra_info` for geometry-aligned speed limits.
    public let requestSegmentSpeedLimits: Bool

    /// Creates routing preferences from UI state.
    public init(
        optimizationMode: OptimizationMode = .fastest,
        avoidTolls: Bool = false,
        avoidFerries: Bool = false,
        avoidTunnels: Bool = false,
        hurryMode: Bool = false,
        isHGVMode: Bool = false,
        avoidResidential: Bool = false,
        avoidCameras: Bool = false,
        avoidHazmatRestricted: Bool = false,
        enforceTurnRadius: Bool = false,
        enforceCurveSpeed: Bool = false,
        vehicle: VehicleProfile = .default,
        algorithm: RoutingAlgorithm = .aStar,
        requestSegmentSpeedLimits: Bool = false
    ) {
        self.optimizationMode = optimizationMode
        self.avoidTolls = avoidTolls
        self.avoidFerries = avoidFerries
        self.avoidTunnels = avoidTunnels
        self.hurryMode = hurryMode
        self.isHGVMode = isHGVMode
        self.avoidResidential = avoidResidential
        self.avoidCameras = avoidCameras
        self.avoidHazmatRestricted = avoidHazmatRestricted
        self.enforceTurnRadius = enforceTurnRadius
        self.enforceCurveSpeed = enforceCurveSpeed
        self.vehicle = vehicle
        self.algorithm = algorithm
        self.requestSegmentSpeedLimits = requestSegmentSpeedLimits
    }

    /// Preference profile for cost model compatibility.
    public var preferenceProfile: PreferenceProfile {
        PreferenceProfile(
            optimizationMode: optimizationMode,
            avoidTolls: avoidTolls,
            avoidFerries: avoidFerries,
            avoidTunnels: avoidTunnels,
            hurryMode: hurryMode,
            isHGVMode: isHGVMode,
            avoidResidential: avoidResidential,
            avoidCameras: avoidCameras,
            avoidHazmatRestricted: avoidHazmatRestricted,
            enforceTurnRadius: enforceTurnRadius,
            enforceCurveSpeed: enforceCurveSpeed
        )
    }

    /// Default routing preferences.
    public static let `default` = RoutingPreferences()
}
