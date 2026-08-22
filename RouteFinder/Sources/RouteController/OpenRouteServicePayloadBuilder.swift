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

        if request.preferences.isHGVMode {
            let restrictions = ORSRestrictions(
                height: request.vehicle.height,
                width: request.vehicle.width,
                weight: request.vehicle.weight
            )
            return ORSDirectionsRequest(
                coordinates: coordinates,
                options: ORSDirectionsOptions(
                    profileParams: ORSProfileParams(restrictions: restrictions),
                    extraInfo: extraInfo
                )
            )
        }

        return ORSDirectionsRequest(
            coordinates: coordinates,
            options: ORSDirectionsOptions(
                profileParams: nil,
                extraInfo: extraInfo
            )
        )
    }

    private static func includeExtraInfo(for request: ExternalRouteRequest) -> Bool {
        request.preferences.requestSegmentSpeedLimits && ORSAPIDefaults.supportsExtraInfo
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
    let profileParams: ORSProfileParams?
    let extraInfo: [String]?

    enum CodingKeys: String, CodingKey {
        case profileParams = "profile_params"
        case extraInfo = "extra_info"
    }
}

struct ORSProfileParams: Encodable {
    let restrictions: ORSRestrictions
}

struct ORSRestrictions: Encodable {
    let height: Double?
    let width: Double?
    let weight: Double?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(weight, forKey: .weight)
    }

    enum CodingKeys: String, CodingKey {
        case height, width, weight
    }
}
