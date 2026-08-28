import Contracts
import Foundation

/// In-memory cache for Overpass `turn:lanes` lookups keyed by a coarse coordinate grid.
public final class OverpassLaneGuidanceCache: @unchecked Sendable {
    /// Shared process-wide cache cleared when a new route loads.
    public static let shared = OverpassLaneGuidanceCache()

    private let lock = NSLock()
    private var entries: [String: String?] = [:]

    init() {}

    /// Clears all cached lane guidance entries.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    /// Returns a cached raw `turn:lanes` tag when present.
    public func cachedTurnLanes(for coordinate: RoutingCoordinate) -> String?? {
        let key = Self.gridKey(for: coordinate)
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    /// Stores a raw `turn:lanes` tag (including `nil` when Overpass had no data).
    public func store(turnLanes: String?, for coordinate: RoutingCoordinate) {
        let key = Self.gridKey(for: coordinate)
        lock.lock()
        defer { lock.unlock() }
        entries[key] = turnLanes
    }

    /// Rounds coordinates to ~11 m cells for deduplication.
    public static func gridKey(for coordinate: RoutingCoordinate) -> String {
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        return "\(lat),\(lon)"
    }
}
