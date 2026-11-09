import Contracts
import CostModel
import CoreLocation
import Foundation

/// Builds map pins for ahead truck parking / layby POIs with CoPilot-style availability colors.
public enum ParkingMapPinBuilder: Sendable {
    /// Default cap for parking markers on the map canvas.
    public static let defaultMaxPins = 8

    /// Builds colored parking pins from truck POIs (fuel / weigh skipped).
    ///
    /// - Parameters:
    ///   - pois: Ahead truck POIs (typically already occupancy-adjusted).
    ///   - reports: Crowd reports for layby tier resolution.
    ///   - maxPins: Maximum markers to return (nearest-first by arc length when present).
    ///   - asOf: Evaluation instant for hour-of-day priors.
    /// - Returns: Route pins with ``RoutePin/PinKind`` parking tiers.
    public static func pins(
        from pois: [TruckPoi],
        reports: [CrowdReport] = [],
        maxPins: Int = defaultMaxPins,
        asOf date: Date = Date()
    ) -> [RoutePin] {
        guard maxPins > 0 else { return [] }
        let parking = pois.compactMap { poi -> (TruckPoi, ParkingAvailabilityTier)? in
            guard let tier = ParkingOccupancyPrior.availabilityTier(
                for: poi,
                reports: reports,
                asOf: date
            ) else {
                return nil
            }
            return (poi, tier)
        }
        let ordered = parking.sorted { lhs, rhs in
            let leftArc = lhs.0.arcLengthAlongRouteMeters ?? Double.greatestFiniteMagnitude
            let rightArc = rhs.0.arcLengthAlongRouteMeters ?? Double.greatestFiniteMagnitude
            if leftArc != rightArc { return leftArc < rightArc }
            return lhs.0.label < rhs.0.label
        }
        return ordered.prefix(maxPins).map { poi, tier in
            RoutePin(
                id: "parking-\(poi.id)",
                coordinate: CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude),
                kind: RoutePin.pinKind(for: tier),
                title: "\(poi.label) · \(tier.displayLabel)"
            )
        }
    }
}
