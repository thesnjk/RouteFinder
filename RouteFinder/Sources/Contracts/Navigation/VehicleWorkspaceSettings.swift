import Foundation

/// Snapshot of sidebar vehicle + routing fields restored between launches.
public struct VehicleWorkspaceSnapshot: Codable, Sendable, Equatable {
    public var vehicleRegistration: String
    public var isHGVMode: Bool
    public var vehicleHeight: String
    public var vehicleWeight: String
    public var vehicleWidth: String
    public var vehicleLength: String
    public var vehicleAxleWeight: String
    public var vehicleGroundClearance: String
    public var vehicleTurningRadius: String
    public var vehicleEnginePowerHP: String
    public var activeProfileName: String?
    public var hazmatClassRaw: String?
    public var emissionClassRaw: String?
    public var vehicleClassOverrideRaw: String?
    public var avoidNonCompliantLEZ: Bool
    public var avoidResidential: Bool

    /// Creates an empty workspace snapshot.
    public init(
        vehicleRegistration: String = "",
        isHGVMode: Bool = false,
        vehicleHeight: String = "",
        vehicleWeight: String = "",
        vehicleWidth: String = "",
        vehicleLength: String = "",
        vehicleAxleWeight: String = "",
        vehicleGroundClearance: String = "",
        vehicleTurningRadius: String = "",
        vehicleEnginePowerHP: String = "",
        activeProfileName: String? = nil,
        hazmatClassRaw: String? = nil,
        emissionClassRaw: String? = nil,
        vehicleClassOverrideRaw: String? = nil,
        avoidNonCompliantLEZ: Bool = true,
        avoidResidential: Bool = true
    ) {
        self.vehicleRegistration = vehicleRegistration
        self.isHGVMode = isHGVMode
        self.vehicleHeight = vehicleHeight
        self.vehicleWeight = vehicleWeight
        self.vehicleWidth = vehicleWidth
        self.vehicleLength = vehicleLength
        self.vehicleAxleWeight = vehicleAxleWeight
        self.vehicleGroundClearance = vehicleGroundClearance
        self.vehicleTurningRadius = vehicleTurningRadius
        self.vehicleEnginePowerHP = vehicleEnginePowerHP
        self.activeProfileName = activeProfileName
        self.hazmatClassRaw = hazmatClassRaw
        self.emissionClassRaw = emissionClassRaw
        self.vehicleClassOverrideRaw = vehicleClassOverrideRaw
        self.avoidNonCompliantLEZ = avoidNonCompliantLEZ
        self.avoidResidential = avoidResidential
    }
}

/// Persists the vehicle sidebar workspace between app launches.
public enum VehicleWorkspaceSettings {
    private static let snapshotKey = "RouteFinder.vehicleWorkspaceSnapshot"

    /// Loads the saved workspace snapshot, if any.
    public static func load(defaults: UserDefaults = .standard) -> VehicleWorkspaceSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(VehicleWorkspaceSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    /// Persists the workspace snapshot.
    public static func save(_ snapshot: VehicleWorkspaceSnapshot, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
