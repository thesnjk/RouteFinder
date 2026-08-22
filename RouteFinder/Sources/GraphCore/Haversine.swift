import Contracts
import Foundation

/// Great-circle distance calculations for spatial queries and A* heuristics.
public enum Haversine {
    /// Mean Earth radius in meters.
    public static let earthRadiusMeters: Double = 6_371_000

    /// Computes the great-circle distance between two coordinates in meters.
    public static func distance(from a: Coordinate, to b: Coordinate) -> Double {
        distance(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    /// Computes the great-circle distance between two nodes in meters.
    public static func distance(from a: Node, to b: Node) -> Double {
        distance(
            lat1: a.latitude, lon1: a.longitude,
            lat2: b.latitude, lon2: b.longitude
        )
    }

    /// Admissible heuristic for A* — straight-line distance in meters.
    public static func heuristic(from a: Node, to b: Node) -> Double {
        distance(from: a, to: b)
    }

    /// Computes the great-circle distance between two lat/lon pairs in meters.
    public static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }
}
