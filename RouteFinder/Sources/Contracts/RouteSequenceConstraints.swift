import Foundation

/// Scheduling and capacity constraints for multi-stop sequence optimization.
public struct RouteSequenceConstraints: Codable, Sendable, Equatable {
    /// A closed delivery or service time window expressed as absolute instants.
    public struct TimeWindow: Codable, Sendable, Equatable {
        /// Inclusive start instant.
        public let start: Date
        /// Inclusive end instant.
        public let end: Date

        /// Creates a time window.
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }

        /// Vroom-compatible UNIX epoch seconds `[start, end]`.
        public func vroomUnixSeconds() -> [Int] {
            let startSeconds = Int(start.timeIntervalSince1970)
            let endSeconds = Int(end.timeIntervalSince1970)
            return [startSeconds, max(startSeconds, endSeconds)]
        }
    }

    /// A pickup-delivery shipment pair for Vroom shipment routing.
    public struct ShipmentPair: Codable, Sendable, Equatable {
        /// Pickup coordinate.
        public let pickup: RoutingCoordinate
        /// Delivery coordinate.
        public let delivery: RoutingCoordinate
        /// Optional pickup time window.
        public let pickupTimeWindow: TimeWindow?
        /// Optional delivery time window.
        public let deliveryTimeWindow: TimeWindow?
        /// Pickup demand units (optional).
        public let pickupAmount: Int?
        /// Delivery demand units (optional).
        public let deliveryAmount: Int?

        /// Creates a shipment pair.
        public init(
            pickup: RoutingCoordinate,
            delivery: RoutingCoordinate,
            pickupTimeWindow: TimeWindow? = nil,
            deliveryTimeWindow: TimeWindow? = nil,
            pickupAmount: Int? = nil,
            deliveryAmount: Int? = nil
        ) {
            self.pickup = pickup
            self.delivery = delivery
            self.pickupTimeWindow = pickupTimeWindow
            self.deliveryTimeWindow = deliveryTimeWindow
            self.pickupAmount = pickupAmount
            self.deliveryAmount = deliveryAmount
        }
    }

    /// Per-stop delivery time windows keyed by geographic coordinate.
    public let stopTimeWindows: [GeoCoordinateKey: TimeWindow]?
    /// Mandatory driver break service durations in seconds.
    public let driverBreakIntervals: [TimeInterval]?
    /// Optional pickup-delivery shipment pairs.
    public let shipments: [ShipmentPair]?

    /// Creates route sequence constraints.
    public init(
        stopTimeWindows: [GeoCoordinateKey: TimeWindow]? = nil,
        driverBreakIntervals: [TimeInterval]? = nil,
        shipments: [ShipmentPair]? = nil
    ) {
        self.stopTimeWindows = stopTimeWindows
        self.driverBreakIntervals = driverBreakIntervals
        self.shipments = shipments
    }

    /// Looks up a time window for a coordinate using epsilon-based key matching.
    public func timeWindow(for coordinate: RoutingCoordinate, epsilonMeters: Double = 1.0) -> TimeWindow? {
        guard let stopTimeWindows else { return nil }
        for (key, window) in stopTimeWindows where key.matches(coordinate, epsilonMeters: epsilonMeters) {
            return window
        }
        return nil
    }
}
