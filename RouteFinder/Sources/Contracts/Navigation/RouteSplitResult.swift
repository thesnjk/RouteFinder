import CoreLocation
import Foundation

/// Geometric split of a route polyline at a projection point.
public struct RouteSplitResult: Sendable {
    /// Coordinates of the traversed (passed) portion including the split point.
    public let traversedPath: [CLLocationCoordinate2D]
    /// Coordinates of the remaining (upcoming) portion including the split point.
    public let remainingPath: [CLLocationCoordinate2D]
    /// Interpolated coordinate at the split location.
    public let splitCoordinate: CLLocationCoordinate2D
    /// Arc length at the split in meters.
    public let splitArcLengthMeters: Double

    /// Creates a route split result.
    public init(
        traversedPath: [CLLocationCoordinate2D],
        remainingPath: [CLLocationCoordinate2D],
        splitCoordinate: CLLocationCoordinate2D,
        splitArcLengthMeters: Double
    ) {
        self.traversedPath = traversedPath
        self.remainingPath = remainingPath
        self.splitCoordinate = splitCoordinate
        self.splitArcLengthMeters = splitArcLengthMeters
    }
}
