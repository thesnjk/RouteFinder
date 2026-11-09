import Contracts
import Foundation

/// Axis-aligned geographic bounding box in decimal degrees.
public struct GeographicBoundingBox: Sendable, Hashable, Codable {
    /// Southern edge latitude.
    public var minLat: Double
    /// Northern edge latitude.
    public var maxLat: Double
    /// Western edge longitude.
    public var minLon: Double
    /// Eastern edge longitude.
    public var maxLon: Double

    /// Creates a bounding box from edge coordinates.
    public init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }

    /// Approximate area in square degrees (for size honesty / auto-prefetch caps).
    public var approximateAreaSquareDegrees: Double {
        max(0, maxLat - minLat) * max(0, maxLon - minLon)
    }
}

/// Helpers for proactive offline H3 corridor prefetch after a route is committed.
public enum OfflineCorridorPrefetch {
    /// Degrees of padding around origin–destination or polyline bboxes (matches hybrid offline find).
    public static let corridorPadDegrees: Double = 0.15

    /// Maximum auto-prefetch area — East Anglia mid-corridor; never UK mainland.
    public static var maxAutoPrefetchAreaSquareDegrees: Double {
        OfflineDownloadRegion.eastAnglia.approximateAreaSquareDegrees
    }

    /// Computes a padded bounding box covering all route coordinates.
    ///
    /// - Parameters:
    ///   - coordinates: Committed route polyline (display or routing coordinates).
    ///   - padDegrees: Latitude/longitude pad on each edge (default ``corridorPadDegrees``).
    /// - Returns: Padded bbox, or `nil` when the coordinate list is empty.
    public static func paddedBoundingBox(
        from coordinates: [Coordinate],
        padDegrees: Double = corridorPadDegrees
    ) -> GeographicBoundingBox? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let pad = max(0, padDegrees)
        return GeographicBoundingBox(
            minLat: minLat - pad,
            maxLat: maxLat + pad,
            minLon: minLon - pad,
            maxLon: maxLon + pad
        )
    }

    /// Whether the bbox is small enough for automatic corridor prefetch (≤ East Anglia area).
    public static func isWithinAutoPrefetchCap(_ box: GeographicBoundingBox) -> Bool {
        box.approximateAreaSquareDegrees <= maxAutoPrefetchAreaSquareDegrees + 1e-9
    }
}
