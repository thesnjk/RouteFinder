import Contracts
import CoreLocation
import Foundation

/// Target field for map pin placement.
public enum MapPinTarget: Hashable, Equatable, Sendable {
    case waypoint(UUID)
    case none
}

/// Map interaction mode for pin placement vs navigation.
public enum MapInteractionMode: Equatable, Sendable {
    case navigate
    case setPin(UUID)
}

/// A pin displayed on the map canvas.
public struct RoutePin: Identifiable, Sendable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let kind: PinKind
    public let title: String

    public enum PinKind: Sendable {
        case start
        case end
        case waypoint
        /// Truck parking / layby — spaces likely (CoPilot-style green).
        case parkingAmple
        /// Truck parking / layby — mixed availability (amber).
        case parkingLimited
        /// Truck parking / layby — likely full (red).
        case parkingFull
    }

    public init(id: String, coordinate: CLLocationCoordinate2D, kind: PinKind, title: String) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        self.title = title
    }

    /// Maps a driver-facing availability tier to a map pin kind.
    public static func pinKind(for tier: ParkingAvailabilityTier) -> PinKind {
        switch tier {
        case .ample: return .parkingAmple
        case .limited: return .parkingLimited
        case .full: return .parkingFull
        }
    }
}

/// Context menu action from map right-click.
public enum MapContextAction: Sendable {
    case setStart
    case setEnd
    case addStop
}
