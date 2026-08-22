/// Penalty and default constants for the cost model.
public enum CostConstants {
    /// Penalty applied when avoiding toll roads.
    public static let tollPenalty: Double = 5000
    /// Penalty applied when avoiding ferries.
    public static let ferryPenalty: Double = 5000
    /// Penalty applied when avoiding tunnels.
    public static let tunnelPenalty: Double = 5000
    /// Base penalty applied for speed camera presence.
    public static let cameraPenalty: Double = 5000
    /// Maximum camera penalty multiplier in hurry mode.
    public static let hurryCameraPenaltyCap: Double = 10.0
    /// Exponent factor for hurry mode camera penalty.
    public static let hurryCameraExponentK: Double = 2.0
    /// Reference speed for camera penalty normalization (km/h).
    public static let hurryCameraSpeedRefKmh: Double = 50.0
    /// Maximum highway speed bonus fraction in hurry mode.
    public static let hurryHighwaySpeedBonus: Double = 0.25
    /// Minimum speed to qualify for highway bias in hurry mode (km/h).
    public static let hurryHighwayMinSpeedKmh: Double = 80.0
    /// Default speed limit in km/h when edge speed is zero.
    public static let defaultSpeedKmh: Double = 50
    /// Penalty for road-type changes in simplest mode (seconds).
    public static let turnPenalty: Double = 30
    /// Bonus (negative cost) for motorway segments in least-stressful mode (seconds).
    public static let motorwayBonus: Double = -500
    /// Reference max speed for A* heuristic scaling (km/h).
    public static let heuristicMaxSpeedKmh: Double = 130.0
}
