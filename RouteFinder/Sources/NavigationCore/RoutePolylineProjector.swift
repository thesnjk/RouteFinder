import Contracts
import Foundation

/// Result of projecting a point onto the route polyline spine.
public struct PolylineProjectionResult: Sendable, Equatable {
    /// Interpolated coordinate on the route centerline.
    public let projectedCoordinate: Coordinate
    /// Index of the segment containing the projection.
    public let segmentIndex: Int
    /// Parameter along the segment in `[0, 1]`.
    public let segmentParameter: Double
    /// Arc length along the route spine in meters.
    public let arcLengthMeters: Double
    /// Bearing of the containing segment in degrees clockwise from north.
    public let segmentBearing: Double
    /// Perpendicular distance from the input point to the segment in meters.
    public let crossTrackDistanceMeters: Double

    /// Creates a polyline projection result.
    public init(
        projectedCoordinate: Coordinate,
        segmentIndex: Int,
        segmentParameter: Double,
        arcLengthMeters: Double,
        segmentBearing: Double,
        crossTrackDistanceMeters: Double
    ) {
        self.projectedCoordinate = projectedCoordinate
        self.segmentIndex = segmentIndex
        self.segmentParameter = segmentParameter
        self.arcLengthMeters = arcLengthMeters
        self.segmentBearing = segmentBearing
        self.crossTrackDistanceMeters = crossTrackDistanceMeters
    }
}

/// Delegate notified when a point is projected onto the route spine.
public protocol RoutePolylineProjectorDelegate: AnyObject, Sendable {
    /// Called after a successful projection.
    func projector(_ projector: RoutePolylineProjector, didProject result: PolylineProjectionResult)
}

/// Projects vehicle coordinates onto the closest segment of a route polyline spine.
public struct RoutePolylineProjector: Sendable {
    /// Default cross-track threshold for GPS map-matching in meters.
    public static let defaultGPSThresholdMeters = 45.0
    /// Cross-track threshold for simulation (on-route by definition).
    public static let simulationThresholdMeters = 0.0

    /// Creates a route polyline projector.
    public init() {}

    /// Projects a point onto the route spine.
    ///
    /// - Parameters:
    ///   - point: Vehicle coordinate to project.
    ///   - spine: Canonical route geometry containing the simulation spine.
    ///   - crossTrackThresholdMeters: Maximum perpendicular distance to accept a match.
    /// - Returns: Projection result, or `nil` when no segment is within threshold.
    public func project(
        point: Coordinate,
        spine: RouteGeometryCanonicalizer.CanonicalRouteGeometry,
        crossTrackThresholdMeters: Double = defaultGPSThresholdMeters
    ) -> PolylineProjectionResult? {
        let coordinates = spine.simulationCoordinates
        guard coordinates.count >= 2 else { return nil }

        var bestDistance = Double.greatestFiniteMagnitude
        var bestArcLength = 0.0
        var bestBearing = 0.0
        var bestSegmentIndex = 0
        var bestParameter = 0.0
        var bestProjected = point

        for index in 0..<(coordinates.count - 1) {
            let from = coordinates[index]
            let to = coordinates[index + 1]
            let segmentLength = haversineMeters(from, to)
            guard segmentLength > 0.5 else { continue }

            let t = clampProjectionParameter(point: point, from: from, to: to)
            let crossTrack = crossTrackDistanceMeters(point: point, from: from, to: to, t: t)
            if crossTrack < bestDistance {
                bestDistance = crossTrack
                bestSegmentIndex = index
                bestParameter = t
                bestArcLength = spine.cumulativeLengths[index] + t * segmentLength
                bestBearing = bearingDegrees(from: from, to: to)
                bestProjected = Coordinate(
                    latitude: from.latitude + t * (to.latitude - from.latitude),
                    longitude: from.longitude + t * (to.longitude - from.longitude),
                    elevationMeters: interpolateElevation(from: from, to: to, t: t)
                )
            }
        }

        guard bestDistance <= crossTrackThresholdMeters || crossTrackThresholdMeters == 0 else {
            return nil
        }

        return PolylineProjectionResult(
            projectedCoordinate: bestProjected,
            segmentIndex: bestSegmentIndex,
            segmentParameter: bestParameter,
            arcLengthMeters: bestArcLength,
            segmentBearing: bestBearing,
            crossTrackDistanceMeters: bestDistance
        )
    }

    private func clampProjectionParameter(
        point: Coordinate,
        from: Coordinate,
        to: Coordinate
    ) -> Double {
        let lat1 = from.latitude
        let lon1 = from.longitude
        let lat2 = to.latitude
        let lon2 = to.longitude
        let latP = point.latitude
        let lonP = point.longitude
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let lengthSquared = dLat * dLat + dLon * dLon
        guard lengthSquared > 1e-12 else { return 0 }
        return max(0, min(1, ((latP - lat1) * dLat + (lonP - lon1) * dLon) / lengthSquared))
    }

    private func crossTrackDistanceMeters(
        point: Coordinate,
        from: Coordinate,
        to: Coordinate,
        t: Double
    ) -> Double {
        let projLat = from.latitude + t * (to.latitude - from.latitude)
        let projLon = from.longitude + t * (to.longitude - from.longitude)
        return haversineMeters(
            point,
            Coordinate(latitude: projLat, longitude: projLon, elevationMeters: nil)
        )
    }

    private func interpolateElevation(from: Coordinate, to: Coordinate, t: Double) -> Double? {
        if let fromElevation = from.elevationMeters, let toElevation = to.elevationMeters {
            return fromElevation + (toElevation - fromElevation) * t
        }
        return from.elevationMeters ?? to.elevationMeters
    }

    private func bearingDegrees(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    private func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
