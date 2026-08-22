/// User routing preferences and optimization settings.
public struct PreferenceProfile: Sendable, Hashable, Codable {
    /// Primary optimization strategy.
    public let optimizationMode: OptimizationMode
    /// Whether to penalize toll roads.
    public let avoidTolls: Bool
    /// Whether to penalize ferry crossings.
    public let avoidFerries: Bool
    /// Whether to penalize tunnels.
    public let avoidTunnels: Bool
    /// Whether hurry mode is active (reduces effective travel time).
    public let hurryMode: Bool
    /// Whether HGV/truck routing mode is active.
    public let isHGVMode: Bool
    /// Whether to avoid residential and service roads in HGV mode.
    public let avoidResidential: Bool
    /// Whether to penalize or avoid speed cameras in all optimization modes.
    public let avoidCameras: Bool
    /// Whether to block hazmat-restricted edges when carrying hazmat cargo.
    public let avoidHazmatRestricted: Bool
    /// Whether to enforce minimum turn radius at junctions.
    public let enforceTurnRadius: Bool
    /// Whether to attach curve-speed advisories to turn instructions.
    public let enforceCurveSpeed: Bool

    /// Creates a preference profile with the given settings.
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
        enforceCurveSpeed: Bool = false
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
    }

    /// Default preferences optimizing for fastest route.
    public static let `default` = PreferenceProfile()
}
