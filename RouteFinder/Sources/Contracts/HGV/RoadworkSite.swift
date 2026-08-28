import Foundation

/// A roadworks / construction site projected onto the active route corridor.
public struct RoadworkSite: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let latitude: Double
    public let longitude: Double
    /// Arc length along the active route spine in meters, when projected.
    public let arcLengthAlongRouteMeters: Double?

    /// Creates a roadwork site.
    public init(
        id: String,
        label: String = "Roadworks",
        latitude: Double,
        longitude: Double,
        arcLengthAlongRouteMeters: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
    }
}

/// Formats roadworks-ahead banner copy for the map HUD.
public enum RoadworksAheadFormatter: Sendable {
    /// Returns banner text for the nearest roadworks site ahead of the driver.
    public static func bannerMessage(
        site: RoadworkSite,
        currentArcLengthMeters: Double
    ) -> String? {
        guard let arc = site.arcLengthAlongRouteMeters else { return nil }
        let remaining = arc - currentArcLengthMeters
        guard remaining > 0 else { return nil }
        let miles = remaining / 1609.34
        if miles >= 1 {
            return String(format: "Roadworks in %.1f mi along route", miles)
        }
        return "Roadworks ahead along route"
    }

    /// Picks the nearest roadworks site ahead on the route.
    public static func nearestAhead(
        sites: [RoadworkSite],
        currentArcLengthMeters: Double,
        maxAheadMeters: Double = 32_000
    ) -> RoadworkSite? {
        sites
            .compactMap { site -> (RoadworkSite, Double)? in
                guard let arc = site.arcLengthAlongRouteMeters else { return nil }
                let remaining = arc - currentArcLengthMeters
                guard remaining > 0, remaining <= maxAheadMeters else { return nil }
                return (site, remaining)
            }
            .min(by: { $0.1 < $1.1 })?
            .0
    }
}
