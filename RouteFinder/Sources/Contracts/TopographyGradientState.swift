/// Brake fade risk severity from sustained downhill thermal loading.
public enum BrakeFadeRisk: String, Codable, Sendable, Hashable, CaseIterable {
    /// Elevated thermal load; monitor braking.
    case elevated
    /// Critical thermal threshold exceeded; reduce speed and recalculate route.
    case critical
}

/// Thermal load thresholds used to classify brake fade risk.
public enum BrakeThermalThresholds: Sendable {
    /// Critical thermal load threshold in joules before brake fade risk is flagged.
    public static let criticalLoadJoules = 8_500_000.0
    /// Elevated thermal load threshold in joules.
    public static let elevatedLoadJoules = 4_000_000.0
}

/// Topographical gradient state at a point along the route.
public struct TopographyGradientState: Codable, Equatable, Sendable, Hashable {
    /// Grade angle in degrees (positive = uphill).
    public let gradeAngleDegrees: Double
    /// Effective maximum acceleration after grade penalty in m/s².
    public let effectiveMaxAccelerationMps2: Double
    /// Accumulated thermal brake load in joules.
    public let thermalLoadJoules: Double
    /// Active brake fade risk, if any.
    public let brakeFadeRisk: BrakeFadeRisk?

    /// Creates a topography gradient state snapshot.
    public init(
        gradeAngleDegrees: Double,
        effectiveMaxAccelerationMps2: Double,
        thermalLoadJoules: Double,
        brakeFadeRisk: BrakeFadeRisk? = nil
    ) {
        self.gradeAngleDegrees = gradeAngleDegrees
        self.effectiveMaxAccelerationMps2 = effectiveMaxAccelerationMps2
        self.thermalLoadJoules = thermalLoadJoules
        self.brakeFadeRisk = brakeFadeRisk
    }
}
