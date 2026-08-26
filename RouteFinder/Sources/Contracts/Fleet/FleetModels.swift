import Foundation

/// Fleet organization tenant.
public struct FleetOrg: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// Vehicle registered to a fleet org.
public struct FleetVehicle: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let orgId: UUID
    public var label: String
    public var registrationPlate: String?
    public var profile: VehicleProfile?

    public init(
        id: UUID = UUID(),
        orgId: UUID,
        label: String,
        registrationPlate: String? = nil,
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.label = label
        self.registrationPlate = registrationPlate
        self.profile = profile
    }
}

/// Lifecycle status for a dispatched trip.
public enum FleetTripStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case draft
    case dispatched
    case accepted
    case optimized
    case rehearsed
    case active
    case completed
}

/// A single stop in a fleet trip.
public struct FleetTripStop: Sendable, Hashable, Codable, Equatable, Identifiable {
    public enum Role: String, Sendable, Hashable, Codable {
        case origin
        case via
        case destination
    }

    public let id: UUID
    public var sequence: Int
    public var label: String
    public var latitude: Double
    public var longitude: Double
    public var role: Role

    public init(
        id: UUID = UUID(),
        sequence: Int,
        label: String,
        latitude: Double,
        longitude: Double,
        role: Role
    ) {
        self.id = id
        self.sequence = sequence
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.role = role
    }
}

/// Dispatched multi-stop job shared between dispatch console and driver device.
public struct FleetTrip: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let orgId: UUID
    public let vehicleId: UUID
    public var status: FleetTripStatus
    public var stops: [FleetTripStop]
    public var vehicleProfile: VehicleProfile?
    public var physicsETASeconds: TimeInterval?
    public var predictiveReport: PredictiveTelemetryReport?
    /// Company-defined break windows allocated by dispatch (planning aid only).
    public var companyBreaks: [CompanyBreakAllocation]
    /// Latest driver-predicted layby merged from snapshots.
    public var predictedLayby: LaybyAdvisory?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        orgId: UUID,
        vehicleId: UUID,
        status: FleetTripStatus = .draft,
        stops: [FleetTripStop],
        vehicleProfile: VehicleProfile? = nil,
        physicsETASeconds: TimeInterval? = nil,
        predictiveReport: PredictiveTelemetryReport? = nil,
        companyBreaks: [CompanyBreakAllocation] = [],
        predictedLayby: LaybyAdvisory? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orgId = orgId
        self.vehicleId = vehicleId
        self.status = status
        self.stops = stops
        self.vehicleProfile = vehicleProfile
        self.physicsETASeconds = physicsETASeconds
        self.predictiveReport = predictiveReport
        self.companyBreaks = companyBreaks
        self.predictedLayby = predictedLayby
        self.updatedAt = updatedAt
    }
}

/// Compact snapshot published by the driver device for dispatch visibility.
public struct FleetTripSnapshot: Sendable, Hashable, Codable, Equatable {
    public let tripId: UUID
    public var status: FleetTripStatus
    public var orderedStopIds: [UUID]
    public var physicsETASeconds: TimeInterval?
    public var predictiveReport: PredictiveTelemetryReport?
    /// Driver device prediction of the layby the driver will need (fused ranker).
    public var predictedLayby: LaybyAdvisory?
    public var updatedAt: Date

    public init(
        tripId: UUID,
        status: FleetTripStatus,
        orderedStopIds: [UUID],
        physicsETASeconds: TimeInterval? = nil,
        predictiveReport: PredictiveTelemetryReport? = nil,
        predictedLayby: LaybyAdvisory? = nil,
        updatedAt: Date = Date()
    ) {
        self.tripId = tripId
        self.status = status
        self.orderedStopIds = orderedStopIds
        self.physicsETASeconds = physicsETASeconds
        self.predictiveReport = predictiveReport
        self.predictedLayby = predictedLayby
        self.updatedAt = updatedAt
    }
}

/// Port for thin fleet dispatch storage / API.
public protocol FleetDispatchPort: Sendable {
    func createOrg(name: String) async throws -> FleetOrg
    func registerVehicle(_ vehicle: FleetVehicle) async throws -> FleetVehicle
    func pushTrip(_ trip: FleetTrip) async throws -> FleetTrip
    func activeTrip(forVehicleId vehicleId: UUID) async throws -> FleetTrip?
    func applySnapshot(_ snapshot: FleetTripSnapshot) async throws -> FleetTrip
    func trip(id: UUID) async throws -> FleetTrip?
    func orgs() async throws -> [FleetOrg]
    func vehicles(forOrgId orgId: UUID) async throws -> [FleetVehicle]
    func createAndPushTrip(
        orgId: UUID,
        vehicleId: UUID,
        stops: [FleetTripStop],
        companyBreaks: [CompanyBreakAllocation],
        vehicleProfile: VehicleProfile?
    ) async throws -> FleetTrip
}

/// Fleet store errors.
public enum FleetStoreError: Error, Sendable, LocalizedError {
    case tripNotFound
    case invalidTrip(String)

    public var errorDescription: String? {
        switch self {
        case .tripNotFound: "Fleet trip not found."
        case .invalidTrip(let message): message
        }
    }
}
