import Contracts
import CoreLocation
import Foundation

/// Splits a display polyline into traversed and remaining geometric buffers at an arc length.
public enum RouteGeometrySplitter: Sendable {
    /// Splits route coordinates at the given arc length.
    ///
    /// - Parameters:
    ///   - displayCoordinates: Map display coordinates for the route.
    ///   - cumulativeLengths: Cumulative arc lengths aligned to display coordinates.
    ///   - splitArcLengthMeters: Arc length at which to split the polyline.
    /// - Returns: Split result with traversed and remaining paths.
    public static func split(
        displayCoordinates: [CLLocationCoordinate2D],
        cumulativeLengths: [Double],
        splitArcLengthMeters: Double
    ) -> RouteSplitResult {
        guard displayCoordinates.count >= 2,
              cumulativeLengths.count == displayCoordinates.count else {
            return RouteSplitResult(
                traversedPath: [],
                remainingPath: displayCoordinates,
                splitCoordinate: displayCoordinates.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                splitArcLengthMeters: 0
            )
        }

        let clampedArc = min(max(splitArcLengthMeters, 0), cumulativeLengths.last ?? 0)

        if clampedArc <= 0 {
            return RouteSplitResult(
                traversedPath: [],
                remainingPath: displayCoordinates,
                splitCoordinate: displayCoordinates[0],
                splitArcLengthMeters: 0
            )
        }

        if clampedArc >= (cumulativeLengths.last ?? 0) {
            return RouteSplitResult(
                traversedPath: displayCoordinates,
                remainingPath: [displayCoordinates.last!],
                splitCoordinate: displayCoordinates.last!,
                splitArcLengthMeters: cumulativeLengths.last ?? 0
            )
        }

        var segmentIndex = 0
        for index in 0..<(cumulativeLengths.count - 1) {
            if clampedArc >= cumulativeLengths[index], clampedArc <= cumulativeLengths[index + 1] {
                segmentIndex = index
                break
            }
        }

        let segmentStart = cumulativeLengths[segmentIndex]
        let segmentEnd = cumulativeLengths[segmentIndex + 1]
        let segmentLength = segmentEnd - segmentStart
        let t = segmentLength > 0 ? (clampedArc - segmentStart) / segmentLength : 0

        let from = displayCoordinates[segmentIndex]
        let to = displayCoordinates[segmentIndex + 1]
        let splitCoordinate = CLLocationCoordinate2D(
            latitude: from.latitude + t * (to.latitude - from.latitude),
            longitude: from.longitude + t * (to.longitude - from.longitude)
        )

        var traversed = Array(displayCoordinates[0...segmentIndex])
        traversed.append(splitCoordinate)

        var remaining = [splitCoordinate]
        if segmentIndex + 1 < displayCoordinates.count {
            remaining.append(contentsOf: displayCoordinates[(segmentIndex + 1)...])
        }

        return RouteSplitResult(
            traversedPath: traversed,
            remainingPath: remaining,
            splitCoordinate: splitCoordinate,
            splitArcLengthMeters: clampedArc
        )
    }
}
