import Contracts
import Foundation

/// Resolves ORS origin/via legs when the cab is not already at the first job stop.
///
/// Keeps job stop IDs / UI waypoints untouched: only the external routing request
/// is adjusted so the vehicle is guided from its current fix to pickup, then along the job.
public enum DeadheadRouteOrigin: Sendable {
    /// Minimum cab-to-first-stop distance (metres) before deadhead is applied.
    public static let defaultThresholdMeters: Double = 250

    /// ORS legs after optional deadhead prepend.
    public struct Legs: Sendable, Equatable {
        /// Routing origin (cab when deadhead applies, otherwise the job origin stop).
        public let origin: RoutingCoordinate
        /// Intermediate waypoints (includes job origin as first via when deadhead applies).
        public let waypoints: [RoutingCoordinate]
        /// Unchanged job destination.
        public let destination: RoutingCoordinate
        /// Whether cab GPS was used as the routing origin.
        public let appliedDeadhead: Bool

        /// Creates resolved routing legs.
        public init(
            origin: RoutingCoordinate,
            waypoints: [RoutingCoordinate],
            destination: RoutingCoordinate,
            appliedDeadhead: Bool
        ) {
            self.origin = origin
            self.waypoints = waypoints
            self.destination = destination
            self.appliedDeadhead = appliedDeadhead
        }
    }

    /// Builds ORS origin/via/destination from job stops and optional cab fix.
    ///
    /// - Parameters:
    ///   - jobOrigin: First dispatched stop (pickup).
    ///   - jobVias: Middle job stops already resolved for routing.
    ///   - jobDestination: Final job stop.
    ///   - cabCoordinate: Live cab GPS when available.
    ///   - deadheadEnabled: Typically `autoFindRoute` on an active fleet dispatch.
    ///   - thresholdMeters: Distance beyond which deadhead applies (default 250 m).
    public static func resolve(
        jobOrigin: RoutingCoordinate,
        jobVias: [RoutingCoordinate],
        jobDestination: RoutingCoordinate,
        cabCoordinate: RoutingCoordinate?,
        deadheadEnabled: Bool,
        thresholdMeters: Double = defaultThresholdMeters
    ) -> Legs {
        guard deadheadEnabled, let cab = cabCoordinate else {
            return Legs(
                origin: jobOrigin,
                waypoints: jobVias,
                destination: jobDestination,
                appliedDeadhead: false
            )
        }

        let distance = haversineMeters(cab, jobOrigin)
        guard distance > thresholdMeters else {
            return Legs(
                origin: jobOrigin,
                waypoints: jobVias,
                destination: jobDestination,
                appliedDeadhead: false
            )
        }

        return Legs(
            origin: cab,
            waypoints: [jobOrigin] + jobVias,
            destination: jobDestination,
            appliedDeadhead: true
        )
    }

    private static func haversineMeters(_ a: RoutingCoordinate, _ b: RoutingCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
