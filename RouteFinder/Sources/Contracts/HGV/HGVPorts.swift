import Foundation

/// Port contracts for HGV navigation modules (I/O at the edges; pure domain in the center).

/// Persists and loads vehicle physical profiles.
public protocol VehicleProfileRepository: Sendable {
    func loadActive() async throws -> ActiveVehicleProfileState?
    func save(_ state: ActiveVehicleProfileState) async throws
}

/// Constraint-aware routing port.
public protocol ConstraintRouterPort: Sendable {
    func route(request: ConstraintRouteRequest) async throws -> ConstraintRouteResponse
    func evaluate(edge: Edge, profile: VehiclePhysicalVector) -> EdgeEvaluation
}

public struct ConstraintRouteRequest: Sendable, Hashable {
    public let originNodeId: String
    public let destinationNodeId: String
    public let profile: VehiclePhysicalVector

    public init(originNodeId: String, destinationNodeId: String, profile: VehiclePhysicalVector) {
        self.originNodeId = originNodeId
        self.destinationNodeId = destinationNodeId
        self.profile = profile
    }
}

public struct ConstraintRouteResponse: Sendable, Hashable {
    public let edgeIds: [String]
    public let totalCost: Double

    public init(edgeIds: [String], totalCost: Double) {
        self.edgeIds = edgeIds
        self.totalCost = totalCost
    }
}

/// Navigation session port for pose / path / profile bumps.
public protocol NavigationSessionPort: Sendable {
    func ingestPose(latitude: Double, longitude: Double, speedMps: Double) async
    func commitPath(edgeSequence: [Edge]) async
    func bumpProfile(_ state: ActiveVehicleProfileState) async -> ConstraintSetChanged
}

/// HOS clock port.
public protocol HosClockPort: Sendable {
<<<<<<< HEAD
    /// Transitions duty mode and persists the duty log.
    func transition(mode: HosDutyEvent) async throws -> HosDutyMode
    /// Forecasts rest insertions for a planned path of segment durations.
    func forecast(pathDurationsSeconds: [TimeInterval]) async -> HosRestInsertionResult
    /// Returns the current advisory remaining-time snapshot for HUD.
    func snapshot() async -> HosClockSnapshot
=======
    func transition(mode: HosDutyEvent) async throws -> HosDutyMode
    func forecast(pathDurationsSeconds: [TimeInterval]) async -> HosRestInsertionResult
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
}

/// Inspection store port.
public protocol InspectionStorePort: Sendable {
    func save(_ record: InspectionRecord) async throws
    func enqueueSync(_ record: InspectionRecord) async throws
}

/// Hazard event source port.
public protocol HazardEventSourcePort: Sendable {
    func subscribe() -> AsyncStream<HazardEvent>
}

/// Truck POI repository port.
public protocol TruckPoiRepositoryPort: Sendable {
    func query(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        profile: VehiclePhysicalVector
    ) async throws -> [TruckPoi]

    /// Queries truck POIs along a route corridor within an ahead distance window.
    func queryAlongRoute(
        route: [Coordinate],
        kinds: Set<TruckPoiKind>,
        aheadMeters: Double,
        fromArcLengthMeters: Double,
        corridorHalfWidthMeters: Double,
        profile: VehiclePhysicalVector
    ) async throws -> [TruckPoi]
}

/// Default ahead window for “truck fuel within 20 miles”.
public enum TruckPoiSearchDefaults {
    public static let twentyMilesMeters: Double = 32_186.8
    public static let corridorHalfWidthMeters: Double = 1_500.0
}

/// Crowd event ingest port.
public protocol CrowdEventIngestPort: Sendable {
    func submit(_ report: CrowdReport) async throws
    func score(reportId: String, inputs: CrowdConfidenceInputs) async -> Double
}

/// Offline graph store port.
public protocol OfflineGraphStorePort: Sendable {
    func ensureCorridor(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) async throws
    func match(latitude: Double, longitude: Double) async throws -> String?
}

/// Dock policy resolver port.
public protocol DockPolicyResolverPort: Sendable {
    func resolveTerminal(requestedNodeId: String) async -> DockSnapTarget
}

/// Driver alert bus port.
public protocol DriverAlertBusPort: Sendable {
    func publish(_ alert: DriverAlert) async
}
