import Contracts
import Foundation

/// A single stop on a route with isolated text and resolution state.
public struct RouteWaypoint: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var role: Role
    public var rawText: String
    public var resolved: ResolvedEndpoint?

    /// Role of this stop in the ordered route.
    public enum Role: String, Sendable {
        case origin
        case destination
        case via
    }

    /// Creates a route waypoint.
    public init(
        id: UUID = UUID(),
        role: Role,
        rawText: String = "",
        resolved: ResolvedEndpoint? = nil
    ) {
        self.id = id
        self.role = role
        self.rawText = rawText
        self.resolved = resolved
    }

    /// Whether the display text exactly matches the resolved label.
    public var isResolved: Bool {
        guard let resolved else { return false }
        return resolved.displayLabel == rawText.trimmingCharacters(in: .whitespaces)
    }

    /// Best available coordinate for map display and routing (routing-ready without requiring snap).
    public var coordinate: Coordinate? {
        resolved?.snappedCoordinate ?? resolved?.rawCoordinate
    }

    /// Coordinate locked at geocoder selection for routing; display text is UI-only.
    public var waypoint: Waypoint? {
        resolved?.waypoint
    }
}
