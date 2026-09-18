import Contracts
import Foundation
import GraphCore

/// Matches authored UK toll advisories against a route polyline.
public enum TollAdvisoryAlongRouteMatcher: Sendable {
    /// Returns catalog advisories whose approach radius intersects any route vertex,
    /// ordered by first hit along the polyline (first matching vertex index).
    public static func advisories(
        along coordinates: [Coordinate],
        catalog: [UKTollAdvisory] = UKTollAdvisoryCatalog.all
    ) -> [UKTollAdvisory] {
        guard coordinates.count >= 2, !catalog.isEmpty else { return [] }

        var hits: [(index: Int, advisory: UKTollAdvisory)] = []
        var seen = Set<String>()

        for advisory in catalog {
            let tollPoint = advisory.coordinate
            var firstIndex: Int?
            for (index, vertex) in coordinates.enumerated() {
                let distance = Haversine.distance(from: vertex, to: tollPoint)
                if distance <= advisory.approachRadiusMeters {
                    firstIndex = index
                    break
                }
            }
            if let firstIndex, !seen.contains(advisory.id) {
                seen.insert(advisory.id)
                hits.append((firstIndex, advisory))
            }
        }

        return hits.sorted { $0.index < $1.index }.map(\.advisory)
    }

    /// Next advisory ahead of the driver along the route within `horizonMeters`.
    public static func nextAdvisory(
        along coordinates: [Coordinate],
        near location: Coordinate,
        horizonMeters: Double = 5_000,
        catalog: [UKTollAdvisory] = UKTollAdvisoryCatalog.all
    ) -> (advisory: UKTollAdvisory, distanceMeters: Double)? {
        let matched = advisories(along: coordinates, catalog: catalog)
        guard !matched.isEmpty else { return nil }

        var best: (UKTollAdvisory, Double)?
        for advisory in matched {
            let distance = Haversine.distance(from: location, to: advisory.coordinate)
            guard distance <= horizonMeters else { continue }
            if let current = best {
                if distance < current.1 {
                    best = (advisory, distance)
                }
            } else {
                best = (advisory, distance)
            }
        }
        return best.map { ($0.0, $0.1) }
    }
}
