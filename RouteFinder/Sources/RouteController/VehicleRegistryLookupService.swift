import Contracts
import Foundation

/// Vehicle classification returned from a registration lookup.
public enum VehicleRegistryType: String, Sendable, Equatable {
    case passengerCar
    case hgv

    /// Display label for UI chips.
    public var displayName: String {
        switch self {
        case .passengerCar: return "Passenger Car"
        case .hgv: return "HGV"
        }
    }
}

/// Resolved vehicle profile from a registration plate lookup.
public struct VehicleRegistryProfile: Sendable, Equatable {
    public let vehicleType: VehicleRegistryType
    public let heightM: Double
    public let widthM: Double
    public let lengthM: Double
    public let weightTonnes: Double
    public let axleCount: Int
    public let enginePowerHP: Double
    public let isHGVMode: Bool
    public let displayName: String
    public let emissionClass: EmissionClass?
    public let registrySource: RegistrySource

    /// Creates a registry profile from lookup results.
    public init(
        vehicleType: VehicleRegistryType,
        heightM: Double,
        widthM: Double,
        lengthM: Double,
        weightTonnes: Double,
        axleCount: Int,
        enginePowerHP: Double,
        isHGVMode: Bool,
        displayName: String = "",
        emissionClass: EmissionClass? = nil,
        registrySource: RegistrySource = .transientHeuristic
    ) {
        self.vehicleType = vehicleType
        self.heightM = heightM
        self.widthM = widthM
        self.lengthM = lengthM
        self.weightTonnes = weightTonnes
        self.axleCount = axleCount
        self.enginePowerHP = enginePowerHP
        self.isHGVMode = isHGVMode
        self.displayName = displayName.isEmpty ? vehicleType.displayName : displayName
        self.emissionClass = emissionClass
        self.registrySource = registrySource
    }
}

/// Legacy synchronous mock registration lookup retained as final fallback.
public enum VehicleRegistryLookupService {
    /// Looks up a registration plate and returns a matching profile, or nil when unknown.
    public static func lookup(registration: String) -> VehicleRegistryProfile? {
        legacyLookup(registration: registration)
    }

    /// Demo and keyword-based mock lookup used by regional fallback.
    public static func legacyLookup(registration: String) -> VehicleRegistryProfile? {
        let normalized = RegistrationNormalizer.normalize(registration)
        guard !normalized.isEmpty else { return nil }

        if normalized == "CAR-REG" || normalized.contains("CAR") {
            return VehicleRegistryProfile(
                vehicleType: .passengerCar,
                heightM: 1.5,
                widthM: 1.8,
                lengthM: 4.5,
                weightTonnes: 1.8,
                axleCount: 2,
                enginePowerHP: 150,
                isHGVMode: false,
                displayName: "Demo Car"
            )
        }

        if normalized == "TRUCK-44T" || normalized.contains("TRUCK") {
            return VehicleRegistryProfile(
                vehicleType: .hgv,
                heightM: 4.0,
                widthM: 2.55,
                lengthM: 16.5,
                weightTonnes: 44.0,
                axleCount: 6,
                enginePowerHP: 500,
                isHGVMode: true,
                displayName: "Demo HGV"
            )
        }

        return nil
    }
}
