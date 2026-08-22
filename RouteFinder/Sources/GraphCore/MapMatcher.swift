import Contracts
import Foundation

/// A road segment used for map matching.
public struct RoadSegment: Sendable {
    /// The underlying graph edge.
    public let edge: Edge
    /// Start coordinate of the segment.
    public let from: Coordinate
    /// End coordinate of the segment.
    public let to: Coordinate

    /// Creates a road segment.
    public init(edge: Edge, from: Coordinate, to: Coordinate) {
        self.edge = edge
        self.from = from
        self.to = to
    }
}

/// Projects geographic coordinates onto road segments.
public enum MapMatcher {
    /// Default maximum snap distance for map matching.
    public static let defaultMaxSnapDistanceMeters = 500.0

    /// Finds the best road match among the given segments.
    public static func bestMatch(
        to coordinate: Coordinate,
        segments: [RoadSegment],
        maxDistanceMeters: Double = defaultMaxSnapDistanceMeters
    ) -> MapMatchResult? {
        var best: MapMatchResult?
        var bestDistance = maxDistanceMeters

        for segment in segments {
            guard let projection = projectPoint(
                      coordinate,
                      ontoSegmentFrom: segment.from,
                      to: segment.to
                  ) else { continue }

            if projection.distanceMeters < bestDistance {
                bestDistance = projection.distanceMeters
                best = MapMatchResult(
                    nodeID: projection.closerEndpoint == .from ? segment.edge.from : segment.edge.to,
                    snappedCoordinate: projection.point,
                    snapDistanceMeters: projection.distanceMeters,
                    roadName: segment.edge.roadName
                )
            }
        }

        return best
    }

    /// Projects a point onto a line segment and returns the closest point on the segment.
    public static func projectPoint(
        _ point: Coordinate,
        ontoSegmentFrom start: Coordinate,
        to end: Coordinate
    ) -> ProjectionResult? {
        let dx = end.longitude - start.longitude
        let dy = end.latitude - start.latitude
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            let distance = Haversine.distance(from: point, to: start)
            return ProjectionResult(point: start, distanceMeters: distance, closerEndpoint: .from)
        }

        let px = point.longitude - start.longitude
        let py = point.latitude - start.latitude
        var t = (px * dx + py * dy) / lengthSquared
        t = max(0, min(1, t))

        let projected = Coordinate(
            latitude: start.latitude + t * dy,
            longitude: start.longitude + t * dx
        )
        let distance = Haversine.distance(from: point, to: projected)
        let distToStart = Haversine.distance(from: projected, to: start)
        let distToEnd = Haversine.distance(from: projected, to: end)
        let closer: ProjectionEndpoint = distToStart <= distToEnd ? .from : .to

        return ProjectionResult(point: projected, distanceMeters: distance, closerEndpoint: closer)
    }

    /// Result of projecting a coordinate onto a segment.
    public struct ProjectionResult: Sendable {
        /// The projected coordinate on the segment.
        public let point: Coordinate
        /// Perpendicular distance from the input point to the segment.
        public let distanceMeters: Double
        /// Which endpoint is closer to the projection.
        public let closerEndpoint: ProjectionEndpoint
    }

    /// Endpoint of a road segment relative to a projection.
    public enum ProjectionEndpoint: Sendable {
        case from
        case to
    }
}
