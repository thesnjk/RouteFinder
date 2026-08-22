import Contracts
import CoreLocation
import GraphCore
import MapLibreUI
import NavigationCore
import RouteController

/// Source geometry used to render the active route on the map.
public enum RouteGeometry: Equatable, Sendable {
    /// Local route following graph node IDs.
    case nodePath([String], graphID: ObjectIdentifier)
    /// External or simplified polyline with optional encoded form for map transfer.
    case polyline(encoded: String?, precision: Int, coordinates: [Coordinate])
}

/// Converts route paths to map coordinates and overlays.
public enum RoutePolyline {
    /// Returns map coordinates for a path of node IDs.
    public static func coordinates(for path: [String], graph: any GraphProtocol) -> [CLLocationCoordinate2D] {
        path.compactMap { id in
            guard let node = graph.node(id: id) else { return nil }
            return CLLocationCoordinate2D(latitude: node.latitude, longitude: node.longitude)
        }
    }

    /// Validates that every path segment has a corresponding graph edge.
    public static func validatePathGeometry(for path: [String], graph: any GraphProtocol) throws {
        guard path.count >= 2 else {
            throw RoutingError.noFeasibleRoute(constraint: "Road geometry unavailable for computed path")
        }

        for index in 0..<(path.count - 1) {
            let fromID = path[index]
            let toID = path[index + 1]
            if graph.edge(from: fromID, to: toID) == nil {
                throw RoutingError.noFeasibleRoute(constraint: "Road geometry unavailable for computed path")
            }
        }
    }

    /// Returns map coordinates following road edges with interpolation for smoother polylines.
    public static func detailedCoordinates(
        for path: [String],
        graph: any GraphProtocol,
        stepMeters: Double = 40
    ) -> [CLLocationCoordinate2D] {
        guard path.count >= 2 else {
            return coordinates(for: path, graph: graph)
        }

        var result: [CLLocationCoordinate2D] = []

        for index in 0..<(path.count - 1) {
            let fromID = path[index]
            let toID = path[index + 1]
            guard let fromNode = graph.node(id: fromID), let toNode = graph.node(id: toID) else { continue }

            let from = CLLocationCoordinate2D(latitude: fromNode.latitude, longitude: fromNode.longitude)
            let to = CLLocationCoordinate2D(latitude: toNode.latitude, longitude: toNode.longitude)

            if result.isEmpty {
                result.append(from)
            }

            let edge = graph.edge(from: fromID, to: toID)
            let distance = edge?.distance ?? Haversine.distance(
                from: Coordinate(latitude: from.latitude, longitude: from.longitude),
                to: Coordinate(latitude: to.latitude, longitude: to.longitude)
            )

            let steps = max(1, Int(distance / stepMeters))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                result.append(CLLocationCoordinate2D(
                    latitude: from.latitude + (to.latitude - from.latitude) * t,
                    longitude: from.longitude + (to.longitude - from.longitude) * t
                ))
            }
        }

        return result
    }

    /// Converts contract coordinates to MapKit/CoreLocation map points.
    public static func mapCoordinates(from coordinates: [Coordinate]) -> [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Converts GeoJSON LineString `[[lon, lat], ...]` pairs to map coordinates.
    public static func coordinates(fromGeoJSONLine coordinates: [[Double]]) -> [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            let lon = pair[0]
            let lat = pair[1]
            guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Decodes an encoded polyline for map display with light simplification when needed.
    public static func decodePolyline(
        _ encoded: String,
        precision: Int = 6
    ) -> [CLLocationCoordinate2D] {
        let decoded = EncodedPolylineDecoder.decodeToMapCoordinates(encoded, precision: precision)
        guard decoded.count > RouteGeometryCanonicalizer.displaySimplificationThreshold else {
            return decoded
        }
        return simplifyForDisplay(decoded, tolerance: RouteGeometryCanonicalizer.displayRDPTolerance)
    }

    /// Simplifies coordinates for map display using Ramer-Douglas-Peucker.
    public static func simplifyForDisplay(
        _ coordinates: [Coordinate],
        tolerance: Double = 0.00005
    ) -> [Coordinate] {
        guard coordinates.count > 2 else { return coordinates }
        return ramerDouglasPeucker(coordinates, tolerance: tolerance)
    }

    /// Simplifies CoreLocation coordinates for map display.
    public static func simplifyForDisplay(
        _ coordinates: [CLLocationCoordinate2D],
        tolerance: Double = 0.00005
    ) -> [CLLocationCoordinate2D] {
        let contractCoords = coordinates.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        return mapCoordinates(from: simplifyForDisplay(contractCoords, tolerance: tolerance))
    }

    private static func ramerDouglasPeucker(_ points: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard points.count > 2 else { return points }

        var maxDistance = 0.0
        var index = 0
        let start = points.first!
        let end = points.last!

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                index = i
                maxDistance = distance
            }
        }

        if maxDistance > tolerance {
            let left = ramerDouglasPeucker(Array(points[0...index]), tolerance: tolerance)
            let right = ramerDouglasPeucker(Array(points[index...]), tolerance: tolerance)
            return left.dropLast() + right
        }

        return [start, end]
    }

    private static func perpendicularDistance(
        _ point: Coordinate,
        lineStart: Coordinate,
        lineEnd: Coordinate
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        if dx == 0 && dy == 0 {
            return hypot(point.longitude - lineStart.longitude, point.latitude - lineStart.latitude)
        }
        let t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy)
            / (dx * dx + dy * dy)
        let clamped = max(0, min(1, t))
        let projLon = lineStart.longitude + clamped * dx
        let projLat = lineStart.latitude + clamped * dy
        return hypot(point.longitude - projLon, point.latitude - projLat)
    }

    /// Densifies coordinates for simulation physics (~15 m steps by default).
    public static func densifyForSimulation(
        _ coordinates: [CLLocationCoordinate2D],
        stepMeters: Double = 15
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }

        var result: [CLLocationCoordinate2D] = [coordinates[0]]
        for index in 0..<(coordinates.count - 1) {
            let from = coordinates[index]
            let to = coordinates[index + 1]
            let fromCoord = Coordinate(latitude: from.latitude, longitude: from.longitude)
            let toCoord = Coordinate(latitude: to.latitude, longitude: to.longitude)
            let distance = Haversine.distance(from: fromCoord, to: toCoord)
            let steps = max(1, Int(distance / stepMeters))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                result.append(CLLocationCoordinate2D(
                    latitude: from.latitude + (to.latitude - from.latitude) * t,
                    longitude: from.longitude + (to.longitude - from.longitude) * t
                ))
            }
        }
        return result
    }

    /// Computes a map region that fits all coordinates.
    public static func mapRegion(for coordinates: [CLLocationCoordinate2D]) -> MapRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        return MapRegion(
            center: center,
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )
    }
}
