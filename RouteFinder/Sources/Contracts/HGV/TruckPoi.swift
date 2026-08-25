import Foundation

/// Commercial truck point-of-interest kinds beyond laybys.
public enum TruckPoiKind: String, Sendable, Hashable, Codable, CaseIterable {
    case layby
    case weighStation
    case overnightSecureParking
    case highFlowDiesel
    case adrCompatibleParking
}

/// A truck-oriented POI with clearance and access attributes.
public struct TruckPoi: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let kind: TruckPoiKind
    public let latitude: Double
    public let longitude: Double
    public let label: String
    public let amenities: Set<String>
    public let maxHeightMeters: Double?
    public let maxLengthMeters: Double?
    public let hgvAccess: Bool
    /// Arc length along the active route spine in meters, when projected.
    public let arcLengthAlongRouteMeters: Double?
    /// Cross-track distance from the route spine in meters, when projected.
    public let distanceFromRouteMeters: Double?
    /// Crowd / catalog confidence in `[0, 1]`.
    public let confidence: Double?

    public init(
        id: String,
        kind: TruckPoiKind,
        latitude: Double,
        longitude: Double,
        label: String,
        amenities: Set<String> = [],
        maxHeightMeters: Double? = nil,
        maxLengthMeters: Double? = nil,
        hgvAccess: Bool = true,
        arcLengthAlongRouteMeters: Double? = nil,
        distanceFromRouteMeters: Double? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
        self.amenities = amenities
        self.maxHeightMeters = maxHeightMeters
        self.maxLengthMeters = maxLengthMeters
        self.hgvAccess = hgvAccess
        self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
        self.distanceFromRouteMeters = distanceFromRouteMeters
        self.confidence = confidence
    }

    /// Returns a copy with updated confidence.
    public func withConfidence(_ value: Double) -> TruckPoi {
        TruckPoi(
            id: id,
            kind: kind,
            latitude: latitude,
            longitude: longitude,
            label: label,
            amenities: amenities,
            maxHeightMeters: maxHeightMeters,
            maxLengthMeters: maxLengthMeters,
            hgvAccess: hgvAccess,
            arcLengthAlongRouteMeters: arcLengthAlongRouteMeters,
            distanceFromRouteMeters: distanceFromRouteMeters,
            confidence: min(1, max(0, value))
        )
    }
}

/// Filters commercial POIs by active vehicle profile fit.
public enum CommercialPoiEngine: Sendable {
    /// Returns POIs inside an axis-aligned bbox that fit the vehicle profile.
    public static func query(
        pois: [TruckPoi],
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        profile: VehiclePhysicalVector
    ) -> [TruckPoi] {
        pois.filter { poi in
            guard poi.hgvAccess else { return false }
            guard poi.latitude >= minLat, poi.latitude <= maxLat else { return false }
            guard poi.longitude >= minLon, poi.longitude <= maxLon else { return false }
            if let maxH = poi.maxHeightMeters, let h = profile.heightMeters, h > maxH {
                return false
            }
            if let maxL = poi.maxLengthMeters, let l = profile.lengthMeters, l > maxL {
                return false
            }
            if poi.kind == .adrCompatibleParking, profile.adrClasses.isEmpty {
                // Still usable, but not required.
            }
            if !profile.adrClasses.isEmpty, poi.kind == .overnightSecureParking {
                // Prefer ADR lots when carrying dangerous goods — still allow others.
            }
            return true
        }
    }

    /// Convenience: convert layby stops into truck POIs.
    public static func fromLaybys(_ laybys: [LaybyStop]) -> [TruckPoi] {
        laybys.map { stop in
            TruckPoi(
                id: stop.id,
                kind: .layby,
                latitude: stop.coordinate.latitude,
                longitude: stop.coordinate.longitude,
                label: stop.label,
                amenities: ["layby"],
                hgvAccess: true,
                arcLengthAlongRouteMeters: stop.arcLengthAlongRouteMeters,
                distanceFromRouteMeters: stop.distanceFromRouteMeters,
                confidence: 0.85
            )
        }
    }

    /// Filters POIs ahead along the route within a distance window.
    public static func ahead(
        pois: [TruckPoi],
        fromArcLengthMeters: Double,
        aheadMeters: Double,
        kinds: Set<TruckPoiKind>? = nil
    ) -> [TruckPoi] {
        let end = fromArcLengthMeters + aheadMeters
        return pois.filter { poi in
            if let kinds, !kinds.contains(poi.kind) { return false }
            guard let arc = poi.arcLengthAlongRouteMeters else { return false }
            return arc >= fromArcLengthMeters && arc <= end
        }
        .sorted { ($0.arcLengthAlongRouteMeters ?? 0) < ($1.arcLengthAlongRouteMeters ?? 0) }
    }
}
