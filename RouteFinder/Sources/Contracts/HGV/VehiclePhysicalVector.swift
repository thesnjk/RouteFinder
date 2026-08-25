import Foundation

/// Physical / regulatory vector used by constraint evaluation and POI filtering.
public struct VehiclePhysicalVector: Sendable, Hashable, Codable, Equatable {
    /// Vehicle height in metres.
    public let heightMeters: Double?
    /// Vehicle width in metres.
    public let widthMeters: Double?
    /// Vehicle length in metres.
    public let lengthMeters: Double?
    /// Gross vehicle weight in tonnes.
    public let weightTonnes: Double?
    /// Per-axle weight in tonnes.
    public let axleWeightTonnes: Double?
    /// ADR / hazmat class codes carried on this trip.
    public let adrClasses: Set<String>
    /// ADR tunnel restriction code raw value, when set.
    public let tunnelRestrictionCode: String?
    /// Emission class raw value, when set.
    public let emissionClass: String?

    /// Creates a physical vector from explicit dimensions.
    public init(
        heightMeters: Double? = nil,
        widthMeters: Double? = nil,
        lengthMeters: Double? = nil,
        weightTonnes: Double? = nil,
        axleWeightTonnes: Double? = nil,
        adrClasses: Set<String> = [],
        tunnelRestrictionCode: String? = nil,
        emissionClass: String? = nil
    ) {
        self.heightMeters = heightMeters
        self.widthMeters = widthMeters
        self.lengthMeters = lengthMeters
        self.weightTonnes = weightTonnes
        self.axleWeightTonnes = axleWeightTonnes
        self.adrClasses = adrClasses
        self.tunnelRestrictionCode = tunnelRestrictionCode
        self.emissionClass = emissionClass
    }

    /// Bridges from the legacy `VehicleProfile` used by the UI and ORS client.
    public static func from(legacy profile: VehicleProfile) -> VehiclePhysicalVector {
        var classes = Set<String>()
        if let hazmat = profile.hazmatClass, hazmat != .none {
            classes.insert(hazmat.rawValue)
        }
        return VehiclePhysicalVector(
            heightMeters: profile.height,
            widthMeters: profile.width,
            lengthMeters: profile.length,
            weightTonnes: profile.weight,
            axleWeightTonnes: profile.axleWeight,
            adrClasses: classes,
            tunnelRestrictionCode: profile.tunnelRestrictionCode.flatMap { $0 == .none ? nil : $0.rawValue },
            emissionClass: profile.emissionClass?.rawValue
        )
    }
}

/// Persisted active vehicle profile plus optional plate metadata.
public struct ActiveVehicleProfileState: Sendable, Hashable, Codable, Equatable {
    /// Physical vector for constraint routing.
    public var physical: VehiclePhysicalVector
    /// Optional registration plate that produced this profile.
    public var registrationPlate: String?
    /// Optional display label.
    public var label: String?

    /// Creates an active profile state.
    public init(
        physical: VehiclePhysicalVector,
        registrationPlate: String? = nil,
        label: String? = nil
    ) {
        self.physical = physical
        self.registrationPlate = registrationPlate
        self.label = label
    }
}

/// Result of evaluating a single edge against a vehicle profile.
public struct EdgeEvaluation: Sendable, Hashable, Codable, Equatable {
    /// Whether the vehicle may legally traverse the edge.
    public let isFeasible: Bool
    /// Soft cost penalty applied when feasible but undesirable.
    public let penalty: Double
    /// Human-readable reason when infeasible or heavily penalised.
    public let reason: String?

    /// Creates an edge evaluation.
    public init(isFeasible: Bool, penalty: Double = 0, reason: String? = nil) {
        self.isFeasible = isFeasible
        self.penalty = penalty
        self.reason = reason
    }

    /// Feasible with no penalty.
    public static let feasible = EdgeEvaluation(isFeasible: true, penalty: 0)
}

/// Whether a mid-trip profile bump changed the active constraint set.
public struct ConstraintSetChanged: Sendable, Hashable, Codable, Equatable {
    /// True when dimensions / hazmat / emission constraints changed.
    public let didChange: Bool
    /// Optional summary of what changed.
    public let summary: String?

    /// Creates a constraint-change result.
    public init(didChange: Bool, summary: String? = nil) {
        self.didChange = didChange
        self.summary = summary
    }

    /// No change detected.
    public static let unchanged = ConstraintSetChanged(didChange: false)
}
