/// Physical and regulatory constraints for a vehicle.
public struct VehicleProfile: Sendable, Hashable, Codable {
    /// Vehicle height in meters.
    public let height: Double?
    /// Vehicle weight in tonnes.
    public let weight: Double?
    /// Vehicle width in meters.
    public let width: Double?
    /// Vehicle length in meters.
    public let length: Double?
    /// Per-axle weight in tonnes.
    public let axleWeight: Double?
    /// Ground clearance in meters.
    public let groundClearance: Double?
    /// Minimum turning radius in meters.
    public let turningRadius: Double?
    /// Hazmat cargo class, if carrying restricted goods.
    public let hazmatClass: HazmatClass?
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
        axleWeight: Double? = nil,
        groundClearance: Double? = nil,
        turningRadius: Double? = nil,
        hazmatClass: HazmatClass? = nil,
        emissionClass: EmissionClass? = nil,
        savedProfileName: String? = nil
    ) {
        self.height = height
        self.weight = weight
        self.width = width
        self.length = length
        self.axleWeight = axleWeight
        self.groundClearance = groundClearance
        self.turningRadius = turningRadius
        self.hazmatClass = hazmatClass
        self.emissionClass = emissionClass
        self.savedProfileName = savedProfileName
    }

    /// A default profile with no dimensional restrictions.
    public static let `default` = VehicleProfile()

    /// UK articulated HGV preset (44 t, 16.5 m).
    public static let ukArtic = VehicleProfile(
        height: 4.0,
        weight: 44,
        width: 2.55,
        length: 16.5,
        axleWeight: 11.5,
        groundClearance: 0.35,
        turningRadius: 12.5,
        savedProfileName: "UK Artic"
    )

    /// UK rigid 26 t preset.
    public static let ukRigid26t = VehicleProfile(
        height: 4.0,
        weight: 26,
        width: 2.55,
        length: 12.0,
        axleWeight: 9.0,
        groundClearance: 0.35,
        turningRadius: 10.0,
        savedProfileName: "Rigid 26t"
    )
}
