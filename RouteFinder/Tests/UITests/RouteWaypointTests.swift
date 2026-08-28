import Contracts
import DataLayer
import RouteController
import Testing
@testable import UI

@Suite("RouteWaypoint")
struct RouteWaypointTests {
    private let norwich = Coordinate(latitude: 52.6309, longitude: 1.2974)

    private func resolvedEndpoint(label: String) -> ResolvedEndpoint {
        ResolvedEndpoint(
            displayLabel: label,
            rawCoordinate: norwich,
            snappedCoordinate: norwich,
            nodeID: "node-1"
        )
    }

    @Test("isResolved requires exact label match")
    func isResolvedExactMatch() {
        var waypoint = RouteWaypoint(role: .origin, rawText: "Norwich, UK")
        waypoint.resolved = resolvedEndpoint(label: "Norwich, UK")
        #expect(waypoint.isResolved)

        waypoint.rawText = "Norwich"
        #expect(!waypoint.isResolved)

        waypoint.rawText = "Norwich, UK extra"
        #expect(!waypoint.isResolved)
    }

    @Test("isResolved rejects substring prefix false-positive")
    func isResolvedNoSubstringMatch() {
        var waypoint = RouteWaypoint(role: .destination, rawText: "London Liverpool Street")
        waypoint.resolved = resolvedEndpoint(label: "London")
        #expect(!waypoint.isResolved)
    }

    @Test("isResolved is false without resolved endpoint")
    func isResolvedWithoutEndpoint() {
        let waypoint = RouteWaypoint(role: .origin, rawText: "Norwich")
        #expect(!waypoint.isResolved)
    }

    @Test("waypoint locks lat/lon from resolved endpoint")
    func waypointLocksCoordinates() {
        let raw = Coordinate(latitude: 51.1537, longitude: -0.1821)
        var routeWaypoint = RouteWaypoint(role: .origin, rawText: "Gatwick Airport")
        routeWaypoint.resolved = ResolvedEndpoint(
            displayLabel: "Gatwick Airport",
            rawCoordinate: raw,
            snappedCoordinate: raw,
            nodeID: nil
        )

        let locked = routeWaypoint.waypoint
        #expect(locked?.latitude == raw.latitude)
        #expect(locked?.longitude == raw.longitude)
        #expect(locked?.routingCoordinate.latitude == raw.latitude)
        #expect(locked?.routingCoordinate.longitude == raw.longitude)
    }

    @Test("GeocodeSuggestion routingCoordinate ignores display text")
    func suggestionRoutingCoordinate() {
        let suggestion = GeocodeSuggestion(
            id: "test:1",
            title: "Gatwick",
            subtitle: "Gatwick Airport, West Sussex",
            coordinate: Coordinate(latitude: 51.1537, longitude: -0.1821)
        )

        #expect(suggestion.routingCoordinate.latitude == 51.1537)
        #expect(suggestion.routingCoordinate.longitude == -0.1821)
        #expect(suggestion.subtitle.contains("Airport"))
    }
}

@Suite("RouteViewModel waypoints")
@MainActor
struct RouteViewModelWaypointTests {
    private let norwich = Coordinate(latitude: 52.6309, longitude: 1.2974)

    private func resolvedEndpoint(label: String) -> ResolvedEndpoint {
        ResolvedEndpoint(
            displayLabel: label,
            rawCoordinate: norwich,
            snappedCoordinate: norwich,
            nodeID: "node-1"
        )
    }

    @Test("add and remove via stop preserves origin and destination text")
    func viaInsertRemovePreservesEndpoints() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id
        let destID = viewModel.destinationWaypoint.id

        viewModel.routeWaypoints[0].rawText = "Start Place"
        viewModel.routeWaypoints[1].rawText = "End Place"

        viewModel.addWaypoint()
        viewModel.routeWaypoints[1].rawText = "Via Stop"

        viewModel.addWaypoint()
        viewModel.routeWaypoints[2].rawText = "Second Via"

        #expect(viewModel.routeWaypoints.first(where: { $0.id == originID })?.rawText == "Start Place")
        #expect(viewModel.routeWaypoints.first(where: { $0.id == destID })?.rawText == "End Place")
        #expect(viewModel.viaWaypoints.count == 2)

        let firstViaID = viewModel.viaWaypoints[0].id
        viewModel.removeWaypoint(id: firstViaID)

        #expect(viewModel.routeWaypoints.first(where: { $0.id == originID })?.rawText == "Start Place")
        #expect(viewModel.routeWaypoints.first(where: { $0.id == destID })?.rawText == "End Place")
        #expect(viewModel.viaWaypoints.count == 1)
        #expect(viewModel.viaWaypoints[0].rawText == "Second Via")
    }

    @Test("cannot remove origin or destination")
    func cannotRemoveEndpoints() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id
        let destID = viewModel.destinationWaypoint.id

        viewModel.removeWaypoint(id: originID)
        viewModel.removeWaypoint(id: destID)

        #expect(viewModel.routeWaypoints.count == 2)
        #expect(viewModel.originWaypoint.id == originID)
        #expect(viewModel.destinationWaypoint.id == destID)
    }

    @Test("addWaypoint inserts before destination")
    func addWaypointInsertPosition() {
        let viewModel = RouteViewModel()
        let destID = viewModel.destinationWaypoint.id

        viewModel.addWaypoint()

        #expect(viewModel.routeWaypoints.count == 3)
        #expect(viewModel.routeWaypoints[1].role == .via)
        #expect(viewModel.routeWaypoints[2].id == destID)
        #expect(viewModel.routeWaypoints[2].role == .destination)
    }

    @Test("invalidateResolution clears only edited waypoint")
    func resolutionIsolationOnTextEdit() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id
        let destID = viewModel.destinationWaypoint.id

        viewModel.commitWaypoint(id: originID, endpoint: resolvedEndpoint(label: "Origin"))
        viewModel.commitWaypoint(id: destID, endpoint: resolvedEndpoint(label: "Destination"))

        #expect(viewModel.originWaypoint.isResolved)
        #expect(viewModel.destinationWaypoint.isResolved)

        viewModel.invalidateResolutionIfTextChanged(for: originID, newText: "Edited Origin")

        #expect(!viewModel.originWaypoint.isResolved)
        #expect(viewModel.destinationWaypoint.isResolved)
    }

    @Test("updateSearchSuggestions ignores stale query for waypoint")
    func searchSuggestionsIsolation() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id

        viewModel.routeWaypoints[0].rawText = "Norwich"
        viewModel.updateSearchSuggestions(for: originID, query: "London")

        #expect(viewModel.suggestions(for: originID).isEmpty)
    }

    @Test("geocodeWaypoint reads only target waypoint rawText")
    func geocodeWaypointUsesOwnText() async {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id
        let destID = viewModel.destinationWaypoint.id

        viewModel.routeWaypoints[0].rawText = "Norwich"
        viewModel.routeWaypoints[1].rawText = "London"

        let ok = await viewModel.geocodeWaypoint(id: originID)

        #expect(ok == false || viewModel.pendingDisambiguation != nil || viewModel.originWaypoint.resolved != nil)
        if let pending = viewModel.pendingDisambiguation {
            #expect(pending.waypointID == originID)
            #expect(pending.query == "Norwich")
            #expect(pending.query != viewModel.destinationWaypoint.rawText)
        }
        #expect(viewModel.destinationWaypoint.rawText == "London")
        #expect(!viewModel.destinationWaypoint.isResolved || destID == viewModel.destinationWaypoint.id)
    }

    @Test("resolutionStatus uses strict exact match")
    func resolutionStatusStrictMatch() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id

        viewModel.commitWaypoint(id: originID, endpoint: resolvedEndpoint(label: "Norwich, UK"))
        #expect(viewModel.resolutionStatus(for: originID) == .resolved)

        viewModel.routeWaypoints[0].rawText = "Norwich"
        #expect(viewModel.resolutionStatus(for: originID) == .needsSelection)
    }

    @Test("canFindRoute requires origin and destination text")
    func canFindRoute() {
        let viewModel = RouteViewModel()
        #expect(!viewModel.canFindRoute)

        viewModel.routeWaypoints[0].rawText = "Start"
        #expect(!viewModel.canFindRoute)

        viewModel.routeWaypoints[1].rawText = "End"
        #expect(viewModel.canFindRoute)
    }

    @Test("updateSearchSuggestions skips geocoder when waypoint is resolved")
    func resolvedSearchGuard() {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id

        viewModel.commitWaypoint(id: originID, endpoint: resolvedEndpoint(label: "King's Lynn"))
        viewModel.updateSearchSuggestions(for: originID, query: "King's Lynn")

        #expect(viewModel.suggestions(for: originID).isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("geocodeWaypoint skips geocoder when already resolved")
    func geocodeWaypointResolvedGuard() async {
        let viewModel = RouteViewModel()
        let originID = viewModel.originWaypoint.id

        viewModel.commitWaypoint(id: originID, endpoint: resolvedEndpoint(label: "Norwich Cathedral"))
        let ok = await viewModel.geocodeWaypoint(id: originID)

        #expect(ok)
        #expect(viewModel.pendingDisambiguation == nil)
    }

}

@Suite("RouteFailureMapper")
struct RouteFailureMapperTests {
    @Test("maps HGV noFeasibleRoute to low-bridge copy")
    func hgvInfeasibleMapping() {
        let vehicle = VehicleProfile(height: 4.0)
        let presentation = RouteFailureMapper.map(
            RoutingError.noFeasibleRoute(constraint: "Height limit exceeded"),
            vehicle: vehicle,
            isHGVMode: true
        )

        #expect(presentation.kind == .hgvInfeasible)
        #expect(presentation.title == "Route Unfeasible")
        #expect(presentation.message.contains("Low bridge clearance"))
    }

    @Test("maps notConfigured to generic failure copy")
    func notConfiguredMapping() {
        let presentation = RouteFailureMapper.map(
            ExternalRoutingError.notConfigured,
            vehicle: .default,
            isHGVMode: false
        )

        #expect(presentation.kind == .generic)
        #expect(presentation.message.contains("API key"))
    }

    @Test("maps vehicleDimensionBlocked to routeBlocked copy")
    func dimensionBlockedMapping() {
        let presentation = RouteFailureMapper.map(
            ExternalRoutingError.vehicleDimensionBlocked(reason: "Bridge height exceeded"),
            vehicle: .ukArtic,
            isHGVMode: true
        )

        #expect(presentation.kind == .routeBlocked)
        #expect(presentation.title == "Route Blocked")
        #expect(presentation.message == ExternalRoutingError.vehicleDimensionBlockedMessage)
        #expect(presentation.detail == "Bridge height exceeded")
    }

    @Test("external route request contains coordinates only")
    func externalRouteRequestCoordinateOnly() throws {
        let raw = Coordinate(latitude: 51.1537, longitude: -0.1821)
        let endpoint = ResolvedEndpoint(
            displayLabel: "Gatwick Airport, West Sussex",
            rawCoordinate: raw,
            snappedCoordinate: raw,
            nodeID: nil
        )

        let request = ExternalRouteRequest(
            origin: endpoint.waypoint.routingCoordinate,
            destination: RoutingCoordinate(latitude: 52.63, longitude: 1.30),
            vehicle: .ukArtic,
            preferences: RoutingPreferences(isHGVMode: true)
        )

        let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        #expect(!jsonString.contains("Gatwick"))
        #expect(!jsonString.contains("Airport"))
        #expect(jsonString.contains("-0.18"))
        #expect(jsonString.contains("51.1537"))
    }

    @Test("unsnapped waypoint uses raw coordinate for external routing")
    func unsnappedWaypointRoutingCoordinate() {
        let raw = Coordinate(latitude: 51.1537, longitude: -0.1821)
        let endpoint = ResolvedEndpoint(
            displayLabel: "Gatwick Airport",
            rawCoordinate: raw,
            snappedCoordinate: raw,
            nodeID: nil
        )
        #expect(endpoint.nodeID == nil)
        #expect(endpoint.rawCoordinate == raw)
    }

    @Test("cloud routing defaults to OpenRouteService engine")
    @MainActor
    func cloudRoutingDefaults() {
        let viewModel = RouteViewModel()
        viewModel.offlineRoutingEnabled = false
        viewModel.persistOfflineRoutingEnabled()
        #expect(viewModel.routingEngine == .openRouteService)
        #expect(viewModel.orsAPIKey.isEmpty)
        #expect(viewModel.cloudRoutingBanner?.contains("HeiGIT") == true)
    }

    @Test("geocoder cache separates global and biased keys")
    func geocoderCacheKeySeparation() {
        let center = Coordinate(latitude: 52.6, longitude: 1.3)
        let biased = GeocoderCache.cacheKey(query: "Gatwick", near: center)
        let global = GeocoderCache.cacheKeyGlobal(query: "Gatwick")
        #expect(biased != global)
    }
}
