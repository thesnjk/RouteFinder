import Contracts
import DataLayer
import Foundation
import GraphCore
import PathfindingEngine

/// Selects between OpenRouteService (online) and tiled offline graph routing.
public struct HybridRoutingPolicy: Sendable, Hashable {
    /// When true, use the tiled graph even if ORS is available.
    public var preferOfflineRouting: Bool
    /// When false, never attempt offline tiled routing.
    public var offlineRoutingEnabled: Bool
    /// Whether an ORS API key is configured.
    public var hasORSAPIKey: Bool
    /// Whether local `*.graphjson` tiles exist and/or a tile server URL is configured.
    public var hasOfflineTilesAvailable: Bool

    /// Creates a hybrid routing policy.
    public init(
        preferOfflineRouting: Bool = false,
        offlineRoutingEnabled: Bool = true,
        hasORSAPIKey: Bool = false,
        hasOfflineTilesAvailable: Bool = false
    ) {
        self.preferOfflineRouting = preferOfflineRouting
        self.offlineRoutingEnabled = offlineRoutingEnabled
        self.hasORSAPIKey = hasORSAPIKey
        self.hasOfflineTilesAvailable = hasOfflineTilesAvailable
    }

    /// Routing backend selection.
    public enum Source: String, Sendable, Hashable {
        case openRouteService
        case offlineTiles
    }

    /// Offline may be used when the toggle is on and tiles (or a tile server) exist.
    public var canUseOffline: Bool {
        offlineRoutingEnabled && hasOfflineTilesAvailable
    }

    /// Preferred primary source before attempting a fallback.
    public var preferredSource: Source {
        if preferOfflineRouting, canUseOffline {
            return .offlineTiles
        }
        if hasORSAPIKey {
            return .openRouteService
        }
        if canUseOffline {
            return .offlineTiles
        }
        return .openRouteService
    }

    /// Whether ORS failure should fall back to offline tiles.
    public var shouldFallbackToOfflineOnORSFailure: Bool {
        canUseOffline && !preferOfflineRouting && hasORSAPIKey
    }

    /// Neither ORS key nor offline tiles are usable.
    public var lacksAnyRoutingBackend: Bool {
        !hasORSAPIKey && !canUseOffline
    }
}

extension RoutePlanner {
    /// Calculates a route on a loaded tiled / local graph between geographic endpoints.
    ///
    /// Snaps `from` / `to` via ``TiledGraph/matchToRoad(to:maxDistanceMeters:)`` (or nearest node)
    /// then runs the configured pathfinding algorithm.
    public func calculateRoute(
        on graph: TiledGraph,
        from: Coordinate,
        to: Coordinate,
        preferences: RoutingPreferences,
        maxSnapDistanceMeters: Double = MapMatcher.defaultMaxSnapDistanceMeters
    ) async throws -> (SearchResult, [Coordinate]) {
        guard graph.nodeCount > 0 else {
            throw RoutingError.graphNotLoaded
        }

        guard let startMatch = graph.matchToRoad(to: from, maxDistanceMeters: maxSnapDistanceMeters)
            ?? nearestMatch(on: graph, coordinate: from, maxDistanceMeters: maxSnapDistanceMeters)
        else {
            throw RoutingError.locationNotFound("No road near origin")
        }
        guard let endMatch = graph.matchToRoad(to: to, maxDistanceMeters: maxSnapDistanceMeters)
            ?? nearestMatch(on: graph, coordinate: to, maxDistanceMeters: maxSnapDistanceMeters)
        else {
            throw RoutingError.locationNotFound("No road near destination")
        }

        let result = try await calculateRoute(
            graph: graph,
            from: startMatch.nodeID,
            to: endMatch.nodeID,
            preferences: preferences
        )

        let coordinates: [Coordinate] = result.path.compactMap { id in
            guard let node = graph.node(id: id) else { return nil }
            return Coordinate(latitude: node.latitude, longitude: node.longitude)
        }
        return (result, coordinates)
    }

    /// Hybrid entry point: prefer ORS when online+keyed, otherwise use an offline store.
    public func calculateHybridRoute(
        request: ExternalRouteRequest,
        policy: HybridRoutingPolicy,
        offlineStore: DiskOfflineGraphStore
    ) async throws -> (SearchResult, [Coordinate], HybridRoutingPolicy.Source) {
        if policy.lacksAnyRoutingBackend {
            throw OfflineGraphStoreError.noTilesAvailable
        }

        switch policy.preferredSource {
        case .offlineTiles:
            do {
                let outcome = try await calculateOfflineRoute(request: request, offlineStore: offlineStore)
                return (outcome.0, outcome.1, .offlineTiles)
            } catch {
                guard policy.hasORSAPIKey else { throw error }
                let (result, response) = try await calculateExternalRoute(request: request)
                return (result, response.coordinates, .openRouteService)
            }
        case .openRouteService:
            do {
                let (result, response) = try await calculateExternalRoute(request: request)
                return (result, response.coordinates, .openRouteService)
            } catch {
                guard policy.shouldFallbackToOfflineOnORSFailure else { throw error }
                let outcome = try await calculateOfflineRoute(request: request, offlineStore: offlineStore)
                return (outcome.0, outcome.1, .offlineTiles)
            }
        }
    }

    private func calculateOfflineRoute(
        request: ExternalRouteRequest,
        offlineStore: DiskOfflineGraphStore
    ) async throws -> (SearchResult, [Coordinate]) {
        let origin = Coordinate(latitude: request.origin.latitude, longitude: request.origin.longitude)
        let destination = Coordinate(latitude: request.destination.latitude, longitude: request.destination.longitude)

        let pad = 0.15
        try await offlineStore.ensureCorridor(
            minLat: min(origin.latitude, destination.latitude) - pad,
            maxLat: max(origin.latitude, destination.latitude) + pad,
            minLon: min(origin.longitude, destination.longitude) - pad,
            maxLon: max(origin.longitude, destination.longitude) + pad
        )

        guard let graph = await offlineStore.currentGraph() else {
            throw RoutingError.graphNotLoaded
        }

        return try await calculateRoute(
            on: graph,
            from: origin,
            to: destination,
            preferences: request.preferences
        )
    }

    private func nearestMatch(
        on graph: TiledGraph,
        coordinate: Coordinate,
        maxDistanceMeters: Double
    ) -> MapMatchResult? {
        guard let node = graph.findNearestNode(to: coordinate) else { return nil }
        let snapped = Coordinate(latitude: node.latitude, longitude: node.longitude)
        let distance = Haversine.distance(from: coordinate, to: snapped)
        guard distance <= maxDistanceMeters else { return nil }
        return MapMatchResult(
            nodeID: node.id,
            snappedCoordinate: snapped,
            snapDistanceMeters: distance,
            roadName: node.name
        )
    }
}
