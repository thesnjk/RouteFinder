/// Physical and regulatory constraints for a vehicle.
public struct VehicleProfile: Sendable, Hashable, Codable {
    /// Vehicle height in meters.
    public let height: Double?
    /// Vehicle weight in tonnes.
    public let weight: Double?
    /// Vehicle width in meters.
    public let width: Double?
    /// Overall bumper-to-bumper length in meters (sent to ORS as `length`).
    public let length: Double?
    /// Number of trailers (0…3). Nil means unknown / legacy profiles.
    public let trailerCount: Int?
    /// Per-axle weight in tonnes.
    public let axleWeight: Double?
    /// Ground clearance in meters.
    public let groundClearance: Double?
    /// Minimum turning radius in meters.
    public let turningRadius: Double?
    /// Hazmat cargo class, if carrying restricted goods.
    public let hazmatClass: HazmatClass?
    /// ADR tunnel restriction code for the load.
    public let tunnelRestrictionCode: TunnelRestrictionCode?
    /// Emission standard for LEZ compatibility.
    public let emissionClass: EmissionClass?
    /// Saved profile name when persisted by the user.
    public let savedProfileName: String?

    /// Creates a vehicle profile with optional dimensional constraints.
    public init(
        height: Double? = nil,
        weight: Double? = nil,
        width: Double? = nil,
        length: Double? = nil,
        trailerCount: Int? = nil,
        axleWeight: Double? = nil,
        groundClearance: Double? = nil,
        turningRadius: Double? = nil,
        hazmatClass: HazmatClass? = nil,
        tunnelRestrictionCode: TunnelRestrictionCode? = nil,
        emissionClass: EmissionClass? = nil,
        savedProfileName: String? = nil
    ) {
        self.height = height
        self.weight = weight
        self.width = width
        self.length = length
        if let trailerCount {
            self.trailerCount = min(max(trailerCount, 0), 3)
        } else {
            self.trailerCount = nil
        }
        self.axleWeight = axleWeight
        self.groundClearance = groundClearance
        self.turningRadius = turningRadius
        self.hazmatClass = hazmatClass
        self.tunnelRestrictionCode = tunnelRestrictionCode
        self.emissionClass = emissionClass
        self.savedProfileName = savedProfileName
    }

    /// Clamped trailer count for UI and sim (0 when unset).
    public var resolvedTrailerCount: Int {
        min(max(trailerCount ?? 0, 0), 3)
    }

    /// Whether map/sim should use articulated cab + trailer bodies.
    ///
    /// Explicit `trailerCount == 0` forces rigid. Explicit `>= 1` forces artic.
    /// When `trailerCount` is nil (legacy), falls back to overall length ≥ 6 m.
    public var usesArticulatedTrailer: Bool {
        if let trailerCount {
            return trailerCount >= 1
        }
        return (length ?? 0) >= 6.0
    }

    /// A default profile with no dimensional restrictions.
    public static let `default` = VehicleProfile()

    /// UK articulated HGV preset (44 t, 16.5 m, one trailer).
    public static let ukArtic = VehicleProfile(
        height: 4.0,
        weight: 44,
        width: 2.55,
        length: 16.5,
        trailerCount: 1,
        axleWeight: 11.5,
        groundClearance: 0.35,
        turningRadius: 12.5,
        savedProfileName: "UK Artic"
    )

    /// UK rigid 26 t preset (no trailer).
    public static let ukRigid26t = VehicleProfile(
        height: 4.0,
        weight: 26,
        width: 2.55,
        length: 12.0,
        trailerCount: 0,
        axleWeight: 9.0,
        groundClearance: 0.35,
        turningRadius: 10.0,
        savedProfileName: "Rigid 26t"
    )
}
