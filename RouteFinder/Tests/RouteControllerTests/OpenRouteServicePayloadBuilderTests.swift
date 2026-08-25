import Contracts
import Foundation
import Testing
@testable import RouteController

@Test func orsPayloadBuilderCoordinateOrderLonLat() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 51.15, longitude: -0.18),
        destination: RoutingCoordinate(latitude: 52.63, longitude: 1.30),
        vehicle: .ukArtic,
        preferences: RoutingPreferences(isHGVMode: true)
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let coordinates = try #require(json["coordinates"] as? [[Double]])

    #expect(coordinates.count == 2)
    #expect(coordinates[0] == [-0.18, 51.15])
    #expect(coordinates[1] == [1.30, 52.63])

    let jsonString = String(data: data, encoding: .utf8) ?? ""
    #expect(!jsonString.contains("Norwich"))
    #expect(!jsonString.contains("London"))
}

@Test func orsPayloadBuilderTruckRestrictions() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: .ukArtic,
        preferences: RoutingPreferences(isHGVMode: true)
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])
    let profileParams = try #require(options["profile_params"] as? [String: Any])
    let restrictions = try #require(profileParams["restrictions"] as? [String: Any])

    #expect(restrictions["height"] as? Double == 4.0)
    #expect(restrictions["width"] as? Double == 2.55)
    #expect(restrictions["weight"] as? Double == 44.0)
    #expect(restrictions["length"] as? Double == 16.5)
    #expect(restrictions["axleload"] as? Double == 11.5)
}

@Test func orsPayloadBuilderFullHazmatAndAvoidFeatures() throws {
    let vehicle = VehicleProfile(
        height: 4.0,
        weight: 40,
        width: 2.55,
        length: 16.5,
        axleWeight: 11.5,
        hazmatClass: .class3,
        tunnelRestrictionCode: .c
    )
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: vehicle,
        preferences: RoutingPreferences(
            avoidTolls: true,
            avoidFerries: true,
            avoidTunnels: true,
            isHGVMode: true
        )
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])
    let avoid = try #require(options["avoid_features"] as? [String])
    #expect(Set(avoid) == Set(["tollways", "ferries", "tunnels"]))

    let profileParams = try #require(options["profile_params"] as? [String: Any])
    let restrictions = try #require(profileParams["restrictions"] as? [String: Any])
    #expect(restrictions["hazmat"] as? Bool == true)
    #expect(restrictions["hazmat_tunnel_restriction_code"] as? String == "C")
    #expect(restrictions["axleload"] as? Double == 11.5)
}

@Test func orsPayloadBuilderOmitsNilRestrictions() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: VehicleProfile(),
        preferences: RoutingPreferences(isHGVMode: true)
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])
    let profileParams = try #require(options["profile_params"] as? [String: Any])
    let restrictions = try #require(profileParams["restrictions"] as? [String: Any])

    #expect(restrictions["height"] == nil)
    #expect(restrictions["width"] == nil)
    #expect(restrictions["weight"] == nil)
}

@Test func orsPayloadBuilderCarModeOmitsProfileParams() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: .default,
        preferences: RoutingPreferences(isHGVMode: false, requestSegmentSpeedLimits: false)
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])

    #expect(options["profile_params"] == nil)
    #expect(options["extra_info"] == nil)
}

@Test func orsPayloadBuilderDefaultOmitsExtraInfo() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: .default,
        preferences: .default
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])

    #expect(options["extra_info"] == nil)
}

@Test func orsPayloadBuilderOmitsExtraInfoWhenHeiGITUnsupported() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.1, longitude: 1.1),
        vehicle: .default,
        preferences: RoutingPreferences(isHGVMode: false, requestSegmentSpeedLimits: true)
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])

    #expect(ORSAPIDefaults.supportsExtraInfo == false)
    #expect(options["extra_info"] == nil)
}

@Test func orsPayloadBuilderWaypoints() throws {
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 52.0, longitude: 1.0),
        destination: RoutingCoordinate(latitude: 52.2, longitude: 1.2),
        waypoints: [RoutingCoordinate(latitude: 52.1, longitude: 1.1)],
        vehicle: .default,
        preferences: .default
    )

    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let coordinates = try #require(json["coordinates"] as? [[Double]])

    #expect(coordinates.count == 3)
    #expect(coordinates[1] == [1.1, 52.1])
}

@Test func routingCoordinateFromGeocodeSuggestion() {
    let suggestion = GeocodeSuggestion(
        id: "test",
        title: "Gatwick Airport",
        subtitle: "Gatwick Airport, Horley, UK",
        coordinate: Coordinate(latitude: 51.1537, longitude: -0.1821)
    )

    let routing = suggestion.routingCoordinate
    #expect(routing.latitude == 51.1537)
    #expect(routing.longitude == -0.1821)
}

@Test func routingCoordinateFromResolvedEndpointPrefersRawWhenUnsnapped() {
    let raw = Coordinate(latitude: 51.15, longitude: -0.18)
    let snapped = Coordinate(latitude: 51.1501, longitude: -0.1801)

    let unsnapped = ResolvedEndpoint(
        displayLabel: "Test",
        rawCoordinate: raw,
        snappedCoordinate: snapped,
        nodeID: nil
    )
    #expect(unsnapped.routingCoordinate.latitude == raw.latitude)

    let snappedEndpoint = ResolvedEndpoint(
        displayLabel: "Test",
        rawCoordinate: raw,
        snappedCoordinate: snapped,
        nodeID: "node-1"
    )
    #expect(snappedEndpoint.routingCoordinate.latitude == snapped.latitude)
}
