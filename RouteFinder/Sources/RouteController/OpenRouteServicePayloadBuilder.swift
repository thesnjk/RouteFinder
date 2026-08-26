import Contracts
import Foundation

/// Builds OpenRouteService HGV directions JSON payloads from routing requests.
public enum OpenRouteServicePayloadBuilder {
    /// Encodes an ORS directions request as JSON `Data`.
    public static func buildData(from request: ExternalRouteRequest) throws -> Data {
        let payload = buildPayload(from: request)
        return try JSONEncoder().encode(payload)
    }

    /// Assembles an ORS directions request with `[lon, lat]` coordinate pairs.
    static func buildPayload(from request: ExternalRouteRequest) -> ORSDirectionsRequest {
        var coordinates: [[Double]] = [
            [request.origin.longitude, request.origin.latitude]
        ]

        for waypoint in request.waypoints {
            coordinates.append([waypoint.longitude, waypoint.latitude])
        }

        coordinates.append([request.destination.longitude, request.destination.latitude])

        validate(coordinates)

        let extraInfo = includeExtraInfo(for: request) ? ["maxspeed"] : nil
        let avoidFeatures = avoidFeatures(from: request.preferences)

        let avoidPolygons = request.avoidPolygons.flatMap { $0.isEmpty ? nil : $0 }

        if request.preferences.isHGVMode {
            let vehicle = request.vehicle
            let restrictions = ORSRestrictions(
                length: vehicle.length,
                width: vehicle.width,
                height: vehicle.height,
                axleload: vehicle.axleWeight,
                weight: vehicle.weight,
                hazmat: hazmatEnabled(for: vehicle),
                hazmatTunnelRestrictionCode: tunnelRestrictionCode(for: vehicle)
            )
            return ORSDirectionsRequest(
                coordinates: coordinates,
                options: ORSDirectionsOptions(
                    avoidFeatures: avoidFeatures,
                    profileParams: ORSProfileParams(restrictions: restrictions),
                    extraInfo: extraInfo,
                    avoidPolygons: avoidPolygons
                )
            )
        }

        return ORSDirectionsRequest(
            coordinates: coordinates,
            options: ORSDirectionsOptions(
                avoidFeatures: avoidFeatures,
                profileParams: nil,
                extraInfo: extraInfo,
                avoidPolygons: avoidPolygons
            )
        )
    }

    private static func includeExtraInfo(for request: ExternalRouteRequest) -> Bool {
        request.preferences.requestSegmentSpeedLimits && ORSAPIDefaults.supportsExtraInfo
    }

    private static func avoidFeatures(from preferences: RoutingPreferences) -> [String]? {
        var features: [String] = []
        if preferences.avoidTolls { features.append("tollways") }
        if preferences.avoidFerries { features.append("ferries") }
        if preferences.avoidTunnels { features.append("tunnels") }
        return features.isEmpty ? nil : features
    }

    private static func hazmatEnabled(for vehicle: VehicleProfile) -> Bool? {
        guard let hazmat = vehicle.hazmatClass, hazmat != .none else { return nil }
        return true
    }

    private static func tunnelRestrictionCode(for vehicle: VehicleProfile) -> String? {
        guard let code = vehicle.tunnelRestrictionCode, code != .none else { return nil }
        return code.rawValue.uppercased()
    }

    private static func validate(_ coordinates: [[Double]]) {
        precondition(coordinates.count >= 2, "ORS route requires at least two coordinates")
        for pair in coordinates {
            precondition(pair.count == 2, "Each coordinate must be [lon, lat]")
            precondition((-90...90).contains(pair[1]), "Latitude must be within [-90, 90]")
            precondition((-180...180).contains(pair[0]), "Longitude must be within [-180, 180]")
        }
    }
}

// MARK: - ORS JSON types

struct ORSDirectionsRequest: Encodable {
    let coordinates: [[Double]]
    let elevation: Bool
    let geometrySimplify: Bool
    let options: ORSDirectionsOptions

    enum CodingKeys: String, CodingKey {
        case coordinates
        case elevation
        case geometrySimplify = "geometry_simplify"
        case options
    }

    init(
        coordinates: [[Double]],
        elevation: Bool = true,
        geometrySimplify: Bool = false,
        options: ORSDirectionsOptions
    ) {
        self.coordinates = coordinates
        self.elevation = elevation
        self.geometrySimplify = geometrySimplify
        self.options = options
    }
}

struct ORSDirectionsOptions: Encodable {
    let avoidFeatures: [String]?
    let profileParams: ORSProfileParams?
    let extraInfo: [String]?
    /// Rings of `[lon, lat]` pairs; encoded as GeoJSON MultiPolygon for ORS.
    let avoidPolygons: [[[Double]]]?

    enum CodingKeys: String, CodingKey {
        case avoidFeatures = "avoid_features"
        case profileParams = "profile_params"
        case extraInfo = "extra_info"
        case avoidPolygons = "avoid_polygons"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(avoidFeatures, forKey: .avoidFeatures)
        try container.encodeIfPresent(profileParams, forKey: .profileParams)
        try container.encodeIfPresent(extraInfo, forKey: .extraInfo)
        if let avoidPolygons, !avoidPolygons.isEmpty {
            try container.encode(ORSAvoidPolygonsGeoJSON(rings: avoidPolygons), forKey: .avoidPolygons)
        }
    }
}

/// GeoJSON MultiPolygon wrapper for ORS `avoid_polygons`.
struct ORSAvoidPolygonsGeoJSON: Encodable {
    let type = "MultiPolygon"
    /// MultiPolygon coordinates: `[polygon][ring][position]` where position is `[lon, lat]`.
    let coordinates: [[[[Double]]]]

    init(rings: [[[Double]]]) {
        // Each input ring becomes one Polygon with a single exterior ring (closed if needed).
        coordinates = rings.map { ring in
            var closed = ring
            if let first = ring.first, let last = ring.last, first != last {
                closed.append(first)
            }
            return [closed]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(avoidFeatures, forKey: .avoidFeatures)
        try container.encodeIfPresent(profileParams, forKey: .profileParams)
        try container.encodeIfPresent(extraInfo, forKey: .extraInfo)
    }
}

struct ORSProfileParams: Encodable {
    let restrictions: ORSRestrictions
}

struct ORSRestrictions: Encodable {
    let length: Double?
    let width: Double?
    let height: Double?
    let axleload: Double?
    let weight: Double?
    let hazmat: Bool?
    let hazmatTunnelRestrictionCode: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(axleload, forKey: .axleload)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(hazmat, forKey: .hazmat)
        try container.encodeIfPresent(hazmatTunnelRestrictionCode, forKey: .hazmatTunnelRestrictionCode)
    }

    enum CodingKeys: String, CodingKey {
        case length, width, height, axleload, weight, hazmat
        case hazmatTunnelRestrictionCode = "hazmat_tunnel_restriction_code"
    }
}
