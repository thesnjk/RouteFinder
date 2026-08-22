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
