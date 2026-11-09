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

    /// Builds colored parking pins from ranked layby advisories (Android `ParkingMapMarkerBuilder` parity).
    ///
    /// - Parameters:
    ///   - advisories: Ranked ahead layby advisories (nearest-first).
    ///   - maxPins: Maximum markers to return.
    /// - Returns: Route pins with occupancy-prior availability tiers.
    public static func pins(
        from advisories: [LaybyAdvisory],
        maxPins: Int = defaultMaxPins
    ) -> [RoutePin] {
        guard maxPins > 0 else { return [] }
        return advisories.prefix(maxPins).map { advisory in
            let tier = ParkingAvailabilityTier(occupancyPrior: advisory.occupancyPrior)
            return RoutePin(
                id: "parking-layby-\(advisory.stop.id)",
                coordinate: CLLocationCoordinate2D(
                    latitude: advisory.stop.coordinate.latitude,
                    longitude: advisory.stop.coordinate.longitude
                ),
                kind: RoutePin.pinKind(for: tier),
                title: "\(advisory.stop.label) · \(tier.displayLabel)"
            )
        }
    }

    /// Merges ranked-layby pins with truck-POI parking pins, preferring advisories on near-duplicate sites.
    public static func mergedParkingPins(
        advisories: [LaybyAdvisory],
        pois: [TruckPoi],
        reports: [CrowdReport] = [],
        maxPins: Int = defaultMaxPins,
        asOf date: Date = Date(),
        dedupeMeters: Double = 75
    ) -> [RoutePin] {
        let advisoryPins = pins(from: advisories, maxPins: maxPins)
        guard advisoryPins.count < maxPins else { return advisoryPins }
        let poiPins = pins(from: pois, reports: reports, maxPins: maxPins, asOf: date)
        var merged = advisoryPins
        for poiPin in poiPins {
            guard merged.count < maxPins else { break }
            let nearAdvisory = advisoryPins.contains { advisoryPin in
                distanceMeters(advisoryPin.coordinate, poiPin.coordinate) <= dedupeMeters
            }
            if nearAdvisory { continue }
            merged.append(poiPin)
        }
        return merged
    }

    private static func distanceMeters(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D
    ) -> Double {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }
}
