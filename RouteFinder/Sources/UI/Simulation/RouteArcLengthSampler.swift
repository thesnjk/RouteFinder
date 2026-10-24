import Contracts
import Foundation

/// Samples coordinates along a densified route by arc length.
public struct RouteArcLengthSampler: Sendable {
    private let densifiedRoute: [Coordinate]
    private let segmentLengths: [Double]
    private let totalRouteLength: Double

    /// Creates a sampler for the given densified route geometry.
    public init(
        densifiedRoute: [Coordinate],
        segmentLengths: [Double],
        totalRouteLength: Double
    ) {
        self.densifiedRoute = densifiedRoute
        self.segmentLengths = segmentLengths
        self.totalRouteLength = totalRouteLength
    }

    /// Returns the coordinate at the given arc length, interpolating elevation when available.
    public func coordinate(at arcLength: Double) -> Coordinate {
        guard !densifiedRoute.isEmpty else {
            return Coordinate(latitude: 0, longitude: 0)
        }

        let clamped = min(max(arcLength, 0), totalRouteLength)
        var remaining = clamped
        for (index, length) in segmentLengths.enumerated() {
            if remaining <= length || index == segmentLengths.count - 1 {
                let t = length > 0 ? min(1, remaining / length) : 0
                let from = densifiedRoute[index]
                let to = densifiedRoute[index + 1]
                let elevation: Double?
                if let fromElevation = from.elevationMeters, let toElevation = to.elevationMeters {
                    elevation = fromElevation + (toElevation - fromElevation) * t
                } else {
                    elevation = from.elevationMeters ?? to.elevationMeters
                }
                return Coordinate(
                    latitude: from.latitude + (to.latitude - from.latitude) * t,
                    longitude: from.longitude + (to.longitude - from.longitude) * t,
                    elevationMeters: elevation
                )
            }
            remaining -= length
        }

        return densifiedRoute.last ?? densifiedRoute[0]
    }

    /// Returns the route tangent bearing in degrees at the given arc length.
    public func bearingDegrees(at arcLength: Double) -> Double {
        guard densifiedRoute.count >= 2 else { return 0 }
        let epsilon = 1.0
        let ahead = coordinate(at: arcLength + epsilon)
        let behind = coordinate(at: max(0, arcLength - epsilon))
        return Self.bearingBetween(from: behind, to: ahead)
    }

    /// Returns a look-ahead coordinate on the polyline tangent at the given arc length.
    public func tangentLookAhead(
        from arcLength: Double,
        distanceMeters: Double
    ) -> Coordinate {
        coordinate(at: arcLength + distanceMeters)
    }

    /// Projects a world coordinate onto the densified route, searching forward from `fromArcLength`.
    ///
    /// Progress is **monotonic**: the returned arc length is never less than `fromArcLength`
    /// (clamped to the route terminus). Used to sync route governors with Ackermann pose.
    public func nearestArcLengthMeters(
        to latitude: Double,
        longitude: Double,
        fromArcLength: Double,
        searchWindowMeters: Double = 250.0
    ) -> Double {
        guard densifiedRoute.count >= 2, !segmentLengths.isEmpty else {
            return min(max(fromArcLength, 0), totalRouteLength)
        }

        let startArc = min(max(fromArcLength, 0), totalRouteLength)
        let endArc = min(totalRouteLength, startArc + max(searchWindowMeters, 1.0))

        var bestArc = startArc
        var bestDistance = Double.greatestFiniteMagnitude

        var segmentStartArc = 0.0
        for (index, length) in segmentLengths.enumerated() {
            let segmentEndArc = segmentStartArc + length
            defer { segmentStartArc = segmentEndArc }

            if segmentEndArc < startArc { continue }
            if segmentStartArc > endArc { break }

            let from = densifiedRoute[index]
            let to = densifiedRoute[min(index + 1, densifiedRoute.count - 1)]
            let (closestArc, distance) = Self.closestPointOnSegment(
                pointLat: latitude,
                pointLon: longitude,
                from: from,
                to: to,
                segmentStartArc: segmentStartArc,
                segmentLength: length
            )
            let clampedArc = min(max(closestArc, startArc), endArc)
            if distance < bestDistance {
                bestDistance = distance
                bestArc = clampedArc
            }
        }

        return min(max(bestArc, startArc), totalRouteLength)
    }

    private static func closestPointOnSegment(
        pointLat: Double,
        pointLon: Double,
        from: Coordinate,
        to: Coordinate,
        segmentStartArc: Double,
        segmentLength: Double
    ) -> (arcLength: Double, distanceMeters: Double) {
        let latRad = pointLat * .pi / 180.0
        let metersPerDegreeLongitude = 111_320.0 * cos(latRad)
        let metersPerDegreeLatitude = 111_320.0

        let ax = (from.longitude - pointLon) * metersPerDegreeLongitude
        let ay = (from.latitude - pointLat) * metersPerDegreeLatitude
        let bx = (to.longitude - pointLon) * metersPerDegreeLongitude
        let by = (to.latitude - pointLat) * metersPerDegreeLatitude
        let abx = bx - ax
        let aby = by - ay
        let abLenSq = abx * abx + aby * aby
        let t: Double
        if abLenSq < 1e-12 {
            t = 0
        } else {
            // Projection of A→P onto A→B in local meters; A is origin relative to P so P is (0,0)
            // Vector AP = -A, AB = (abx, aby)
            let apx = -ax
            let apy = -ay
            t = min(1, max(0, (apx * abx + apy * aby) / abLenSq))
        }
        let closestX = ax + abx * t
        let closestY = ay + aby * t
        let distance = sqrt(closestX * closestX + closestY * closestY)
        return (segmentStartArc + segmentLength * t, distance)
    }

    private static func bearingBetween(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        var value = bearing.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }
}
