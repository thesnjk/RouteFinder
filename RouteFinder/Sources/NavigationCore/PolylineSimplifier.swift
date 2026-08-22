import Contracts
import CoreLocation
import Foundation

/// Ramer-Douglas-Peucker simplification for map display polylines.
enum PolylineSimplifier {
    /// Simplifies CoreLocation coordinates for map display.
    static func simplifyForDisplay(
        _ coordinates: [CLLocationCoordinate2D],
        tolerance: Double = 0.00005
    ) -> [CLLocationCoordinate2D] {
        let contractCoords = coordinates.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        return contractCoordsToMap(simplifyForDisplay(contractCoords, tolerance: tolerance))
    }

    private static func contractCoordsToMap(_ coordinates: [Coordinate]) -> [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private static func simplifyForDisplay(
        _ coordinates: [Coordinate],
        tolerance: Double
    ) -> [Coordinate] {
        guard coordinates.count > 2 else { return coordinates }
        return ramerDouglasPeucker(coordinates, tolerance: tolerance)
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
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-12 else {
            let dLat = point.latitude - lineStart.latitude
            let dLon = point.longitude - lineStart.longitude
            return sqrt(dLat * dLat + dLon * dLon)
        }
        let t = max(0, min(1, (
            (point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy
        ) / lengthSquared))
        let projLon = lineStart.longitude + t * dx
        let projLat = lineStart.latitude + t * dy
        let dLat = point.latitude - projLat
        let dLon = point.longitude - projLon
        return sqrt(dLat * dLat + dLon * dLon)
    }
}
