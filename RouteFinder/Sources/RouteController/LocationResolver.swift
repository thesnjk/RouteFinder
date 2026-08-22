import Contracts
import CoreLocation
import Foundation
import GraphCore

/// Resolves location strings and coordinates to graph node IDs.
public actor LocationResolver {
    private var cache: [String: String] = [:]
    private var reverseCache: [String: String] = [:]
    private let geocoder = CLGeocoder()

    public init() {}

    /// Reverse-geocodes a coordinate to a human-readable label.
    public func reverseGeocode(coordinate: Coordinate) async -> String {
        let key = "rev:\(coordinate.latitude),\(coordinate.longitude)"
        if let cached = reverseCache[key] {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let label = formatPlacemark(placemarks.first)
                ?? String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
            reverseCache[key] = label
            return label
        } catch {
            let fallback = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
            reverseCache[key] = fallback
            return fallback
        }
    }

    private func formatPlacemark(_ placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let parts = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    /// Resolves a location string to a graph node ID.
    public func resolve(location: String, graph: any GraphProtocol) async throws -> String {
        if let cached = cache[location] {
            return cached
        }

        if let matched = graph.matchingNodeID(for: location) {
            cache[location] = matched
            return matched
        }

        if graph.node(id: location) != nil {
            cache[location] = location
            return location
        }

        do {
            let placemarks = try await geocoder.geocodeAddressString(location)
            if let coordinate = placemarks.first?.location?.coordinate {
                let match = try matchAndResolve(
                    coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    graph: graph,
                    cacheKey: location
                )
                return match.nodeID
            }
        } catch {
            // Geocoding failed; fall through to error below.
        }

        throw RoutingError.locationNotFound(location)
    }

    /// Resolves a coordinate to a graph node ID.
    public func resolve(coordinate: Coordinate, graph: any GraphProtocol, cacheKey: String? = nil) throws -> String {
        try matchAndResolve(coordinate: coordinate, graph: graph, cacheKey: cacheKey).nodeID
    }

    /// Snaps a coordinate to the road network and returns full match metadata.
    public func matchAndResolve(
        coordinate: Coordinate,
        graph: any GraphProtocol,
        maxDistanceMeters: Double = MapMatcher.defaultMaxSnapDistanceMeters,
        cacheKey: String? = nil,
        allowUnsnapped: Bool = false
    ) throws -> MapMatchResult {
        let key = cacheKey ?? "\(coordinate.latitude),\(coordinate.longitude)"
        if let cached = cache[key], let node = graph.node(id: cached) {
            return MapMatchResult(
                nodeID: cached,
                snappedCoordinate: Coordinate(latitude: node.latitude, longitude: node.longitude),
                snapDistanceMeters: Haversine.distance(
                    from: coordinate,
                    to: Coordinate(latitude: node.latitude, longitude: node.longitude)
                ),
                roadName: node.name
            )
        }

        guard let match = graph.matchToRoad(to: coordinate, maxDistanceMeters: maxDistanceMeters) else {
            if allowUnsnapped {
                return MapMatchResult(
                    nodeID: "",
                    snappedCoordinate: coordinate,
                    snapDistanceMeters: 0,
                    roadName: nil
                )
            }
            if let nearest = graph.findNearestNode(to: coordinate) {
                let snapped = Coordinate(latitude: nearest.latitude, longitude: nearest.longitude)
                let distance = Haversine.distance(from: coordinate, to: snapped)
                throw RoutingError.snapTooFar(distance: distance, maxDistance: maxDistanceMeters)
            }
            throw RoutingError.locationNotFound(key)
        }

        let connectedID = ConnectedNodeFinder.findNearestConnectedNode(startingFrom: match.nodeID, graph: graph) ?? match.nodeID
        cache[key] = connectedID
        return MapMatchResult(
            nodeID: connectedID,
            snappedCoordinate: match.snappedCoordinate,
            snapDistanceMeters: match.snapDistanceMeters,
            roadName: match.roadName
        )
    }

    /// Resolves an endpoint for routing, optionally allowing unsnapped coordinates.
    public func resolveForRouting(
        endpoint: ResolvedEndpoint,
        graph: any GraphProtocol,
        allowUnsnapped: Bool = false
    ) throws -> String? {
        if let nodeID = endpoint.nodeID, !nodeID.isEmpty {
            return nodeID
        }
        if allowUnsnapped {
            return nil
        }
        return try resolve(coordinate: endpoint.rawCoordinate, graph: graph, cacheKey: endpoint.displayLabel)
    }

    /// Clears the geocoding cache.
    public func clearCache() {
        cache.removeAll()
        reverseCache.removeAll()
    }
}
