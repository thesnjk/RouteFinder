import Contracts
import DataLayer
import Foundation
import RouteController

/// Inputs for scheduling a traffic-aware alternate evaluation.
@MainActor
public struct TrafficRerouteScheduleInputs: Sendable {
    /// Original outbound ORS request.
    public let request: ExternalRouteRequest
    /// Original successful ORS response.
    public let original: ExternalRouteResponse
    /// Whether traffic-avoid routing is enabled.
    public let avoidTrafficDelaysWhenRouting: Bool
    /// TomTom Traffic Flow API key (empty when unset).
    public let tomTomAPIKey: String
    /// HeiGIT ORS API key (empty when unset).
    public let orsAPIKey: String
    /// Vehicle profile for TomTom hazard thresholds.
    public let vehicleProfile: VehicleSpecificationProfile
    /// Display measurement system for copy.
    public let measurementSystem: RegionalMeasurementSystem

    /// Creates traffic reroute schedule inputs.
    public init(
        request: ExternalRouteRequest,
        original: ExternalRouteResponse,
        avoidTrafficDelaysWhenRouting: Bool,
        tomTomAPIKey: String,
        orsAPIKey: String,
        vehicleProfile: VehicleSpecificationProfile,
        measurementSystem: RegionalMeasurementSystem
    ) {
        self.request = request
        self.original = original
        self.avoidTrafficDelaysWhenRouting = avoidTrafficDelaysWhenRouting
        self.tomTomAPIKey = tomTomAPIKey
        self.orsAPIKey = orsAPIKey
        self.vehicleProfile = vehicleProfile
        self.measurementSystem = measurementSystem
    }
}

/// Host surface for route-planning orchestration owned by ``RouteViewModel``.
@MainActor
public protocol RoutePlanningHost: AnyObject {
    /// Whether a route calculation is in progress.
    var isCalculating: Bool { get set }
    /// Inline error banner text.
    var errorMessage: String? { get set }
    /// Modal route failure presentation.
    var routeFailure: RouteFailurePresentation? { get set }
    /// Increments when the route detail sheet should collapse.
    var routeDetailCollapseTick: Int { get set }
    /// Latest search / route result.
    var result: SearchResult? { get set }
    /// Whether a traffic alternate is available to apply.
    var trafficRerouteAvailable: Bool { get set }
    /// Whether traffic alternate evaluation is running.
    var isEvaluatingTrafficReroute: Bool { get set }
    /// Pending traffic-aware alternate response.
    var pendingTrafficAlternate: ExternalRouteResponse? { get set }
    /// Clears map polyline and related geometry state.
    func clearRouteGeometry()
    /// Applies enriched turn instructions after Overpass / heuristic enrichment.
    func applyLaneGuidanceEnrichment(_ instructions: [TurnInstruction])
    /// Runs a full route calculation when origin and destination are resolved.
    func calculateRoute() async
}

/// Coordinates route calculation helpers, recalculate debounce, lane enrichment, and traffic reroute evaluation.
@MainActor
public final class RoutePlanningCoordinator {
    private weak var host: RoutePlanningHost?
    private var recalculateTask: Task<Void, Never>?
    private var laneEnrichmentTask: Task<Void, Never>?
    private var trafficRerouteTask: Task<Void, Never>?
    private var activeRouteGeneration: UInt64 = 0

    /// Creates a route planning coordinator bound to the given host.
    public init(host: RoutePlanningHost) {
        self.host = host
    }

    /// Builds a ``SearchResult`` from an ORS external route response.
    public static func searchResult(
        from response: ExternalRouteResponse,
        preferences: RoutingPreferences,
        turnInstructions: [TurnInstruction]
    ) -> SearchResult {
        let distanceLabel = response.distanceMeters >= 1000
            ? String(format: "%.1f km", response.distanceMeters / 1000)
            : String(format: "%.0f m", response.distanceMeters)
        let profileLabel = preferences.isHGVMode ? "HGV" : "Car"
        return SearchResult(
            path: ["external-ors"],
            totalDistance: response.distanceMeters,
            totalTime: response.durationSeconds,
            nodesVisited: response.coordinates.count,
            runtime: 0,
            explanation: "HeiGIT \(profileLabel) route · \(distanceLabel)",
            turnInstructions: turnInstructions,
            metrics: RouteMetrics(
                totalDistance: response.distanceMeters,
                totalTime: response.durationSeconds,
                searchCost: response.durationSeconds,
                speedCameraCount: 0,
                tollSegmentCount: 0,
                ferrySegmentCount: 0,
                tunnelSegmentCount: 0
            )
        )
    }

    /// Maps maneuvers (or densified polyline) to turn instructions with heuristic lane guidance.
    public static func heuristicTurnInstructions(from response: ExternalRouteResponse) -> [TurnInstruction] {
        let turnInstructions: [TurnInstruction]
        if !response.maneuvers.isEmpty {
            turnInstructions = ORSTurnInstructionMapper.map(
                maneuvers: response.maneuvers,
                coordinates: response.coordinates
            )
        } else {
            turnInstructions = PolylineTurnInstructionGenerator.generate(
                coordinates: response.coordinates
            )
        }
        return LaneGuidanceEnricher.enrichWithHeuristics(instructions: turnInstructions)
    }

    /// ORS avoid rings for non-compliant UK LEZ / CAZ zones (`nil` when empty / disabled).
    public static func lezAvoidPolygons(
        emissionClass: EmissionClass?,
        avoidEnabled: Bool,
        origin: RoutingCoordinate,
        destination: RoutingCoordinate
    ) -> [[[Double]]]? {
        let rings = LEZAvoidPolicy.polygons(
            emissionClass: emissionClass,
            avoidEnabled: avoidEnabled,
            destination: Coordinate(latitude: destination.latitude, longitude: destination.longitude),
            origin: Coordinate(latitude: origin.latitude, longitude: origin.longitude)
        )
        return rings.isEmpty ? nil : rings
    }

    /// Maps a routing error into host-visible failure presentation and clears geometry.
    public func presentRouteError(_ error: Error, preferences: RoutingPreferences) {
        guard let host else { return }
        let presentation = RouteFailureMapper.map(
            error,
            vehicle: preferences.vehicle,
            isHGVMode: preferences.isHGVMode
        )
        host.errorMessage = presentation.message
        host.routeFailure = presentation
        host.routeDetailCollapseTick &+= 1
        host.result = nil
        host.clearRouteGeometry()
    }

    /// Debounces recalculation until origin and destination are both resolved.
    public func recalculateIfReady(originResolved: Bool, destinationResolved: Bool) {
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self, let host = self.host else { return }
            guard originResolved, destinationResolved else {
                host.clearRouteGeometry()
                host.result = nil
                host.errorMessage = nil
                return
            }
            await host.calculateRoute()
        }
    }

    /// Cancels pending recalculate / enrichment / traffic tasks and resets generation.
    public func cancelPendingWork() {
        recalculateTask?.cancel()
        recalculateTask = nil
        laneEnrichmentTask?.cancel()
        laneEnrichmentTask = nil
        trafficRerouteTask?.cancel()
        trafficRerouteTask = nil
        activeRouteGeneration = 0
    }

    /// Schedules Overpass (optional) lane-guidance enrichment for the active route generation.
    public func scheduleLaneGuidanceEnrichment(
        instructions: [TurnInstruction],
        coordinates: [Coordinate],
        queryOverpass: Bool = true
    ) {
        laneEnrichmentTask?.cancel()
        OverpassLaneGuidanceClient.clearCache()
        activeRouteGeneration &+= 1
        let generation = activeRouteGeneration
        let options = LaneGuidanceEnrichmentOptions(queryOverpass: queryOverpass)

        laneEnrichmentTask = Task { @MainActor [weak self] in
            let enriched = await LaneGuidanceEnricher.enrichWithOverpass(
                instructions: instructions,
                coordinates: coordinates,
                options: options
            )
            guard !Task.isCancelled,
                  let self,
                  let host = self.host,
                  self.activeRouteGeneration == generation else { return }
            host.applyLaneGuidanceEnrichment(enriched)
        }
    }

    /// Refreshes a single upcoming maneuver with Overpass when guidance is still heuristic-only.
    public func scheduleSingleManeuverLaneRefresh(
        instruction: TurnInstruction,
        coordinate: Coordinate,
        allInstructions: [TurnInstruction]
    ) {
        guard instruction.laneGuidance?.source != .osm else { return }
        guard instruction.maneuver != .arrive, instruction.maneuver != .depart else { return }

        Task { @MainActor [weak self] in
            let client = OverpassLaneGuidanceClient()
            let routingCoord = RoutingCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            guard let osm = try? await client.fetchLaneGuidance(
                near: routingCoord,
                searchRadiusMeters: 40,
                maneuver: instruction.maneuver
            ), let host = self?.host else { return }

            let updated = allInstructions.map { existing in
                guard existing.id == instruction.id else { return existing }
                return TurnInstruction(
                    id: existing.id,
                    maneuver: existing.maneuver,
                    roadName: existing.roadName,
                    distance: existing.distance,
                    bearing: existing.bearing,
                    recommendedSpeedKmh: existing.recommendedSpeedKmh,
                    laneGuidance: osm
                )
            }
            host.applyLaneGuidanceEnrichment(updated)
        }
    }

    /// Optionally samples TomTom along the route and prepares an avoid-polygon alternate.
    public func scheduleTrafficRerouteEvaluation(inputs: TrafficRerouteScheduleInputs) {
        guard let host else { return }
        trafficRerouteTask?.cancel()
        host.trafficRerouteAvailable = false
        host.pendingTrafficAlternate = nil
        let tomTomKey = inputs.tomTomAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let orsKey = inputs.orsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard inputs.avoidTrafficDelaysWhenRouting,
              !tomTomKey.isEmpty,
              !orsKey.isEmpty else {
            host.isEvaluatingTrafficReroute = false
            return
        }

        host.isEvaluatingTrafficReroute = true
        trafficRerouteTask = Task { @MainActor [weak self] in
            defer { self?.host?.isEvaluatingTrafficReroute = false }
            do {
                let trafficClient = try TomTomTrafficFlowClient(apiKey: tomTomKey)
                let routingClient = try OpenRouteServiceRoutingClient(apiKey: orsKey)
                let coordinator = TrafficRerouteCoordinator(
                    trafficClient: trafficClient,
                    routingClient: routingClient
                )
                let context = TrafficRerouteEvaluationContext(
                    vehicleProfile: inputs.vehicleProfile,
                    measurementSystem: inputs.measurementSystem
                )
                let outcome = await coordinator.evaluate(
                    request: inputs.request,
                    original: inputs.original,
                    context: context
                )
                guard !Task.isCancelled, let host = self?.host else { return }
                if let alternate = outcome.alternate {
                    host.pendingTrafficAlternate = alternate
                    host.trafficRerouteAvailable = true
                } else {
                    host.trafficRerouteAvailable = false
                    host.pendingTrafficAlternate = nil
                }
            } catch {
                guard !Task.isCancelled, let host = self?.host else { return }
                host.trafficRerouteAvailable = false
                host.pendingTrafficAlternate = nil
            }
        }
    }
}
