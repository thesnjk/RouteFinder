import Contracts
import Foundation
import Testing
@testable import RouteController

@Test func trafficAvoidPolygonBuilderCreatesClosedRingAroundSegment() {
    let from = Coordinate(latitude: 51.50, longitude: -0.12)
    let to = Coordinate(latitude: 51.51, longitude: -0.10)
    let ring = TrafficAvoidPolygonBuilder.corridorRing(
        from: from,
        to: to,
        halfWidthMeters: 400,
        extendMeters: 500
    )

    #expect(ring != nil)
    let points = try! #require(ring)
    #expect(points.count == 5)
    #expect(points.first == points.last)
    for point in points {
        #expect(point.count == 2)
        #expect((-180...180).contains(point[0]))
        #expect((-90...90).contains(point[1]))
    }
}

@Test func trafficAvoidPolygonBuilderBuildsPolygonsForJammedSamples() {
    let route = [
        Coordinate(latitude: 51.50, longitude: -0.20),
        Coordinate(latitude: 51.505, longitude: -0.15),
        Coordinate(latitude: 51.51, longitude: -0.10),
        Coordinate(latitude: 51.52, longitude: -0.05),
    ]
    let jammed = [Coordinate(latitude: 51.505, longitude: -0.15)]
    let polygons = TrafficAvoidPolygonBuilder.polygons(along: route, jammedSamples: jammed)
    #expect(polygons.count == 1)
    #expect(polygons[0].count >= 4)
    #expect(polygons[0].first == polygons[0].last)
}

@Test func trafficRerouteCoordinatorSamplesAlongPolyline() {
    let route = [
        Coordinate(latitude: 51.0, longitude: 0.0),
        Coordinate(latitude: 51.1, longitude: 0.1),
        Coordinate(latitude: 51.2, longitude: 0.2),
    ]
    let samples = TrafficRerouteCoordinator.sampleCoordinates(along: route, intervalMeters: 5_000)
    #expect(!samples.isEmpty)
    #expect(samples.count >= 2)
}

@Test func orsPayloadBuilderEncodesAvoidPolygons() throws {
    let ring: [[Double]] = [
        [-0.12, 51.50],
        [-0.10, 51.50],
        [-0.10, 51.52],
        [-0.12, 51.52],
        [-0.12, 51.50],
    ]
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 51.15, longitude: -0.18),
        destination: RoutingCoordinate(latitude: 52.63, longitude: 1.30),
        vehicle: .ukArtic,
        preferences: RoutingPreferences(isHGVMode: true),
        avoidPolygons: [ring]
    )
    let data = try OpenRouteServicePayloadBuilder.buildData(from: request)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let options = try #require(json["options"] as? [String: Any])
    let avoid = try #require(options["avoid_polygons"] as? [String: Any])
    #expect(avoid["type"] as? String == "MultiPolygon")
    let coordinates = try #require(avoid["coordinates"] as? [[[[Double]]]])
    #expect(coordinates.count == 1)
}

@Test func trafficRerouteCoordinatorRejectsMarginalAlternate() {
    let original = ExternalRouteResponse(
        coordinates: [Coordinate(latitude: 51.5, longitude: -0.1)],
        distanceMeters: 100_000,
        durationSeconds: 3600,
        maneuvers: []
    )
    let marginal = ExternalRouteResponse(
        coordinates: [Coordinate(latitude: 51.5, longitude: -0.2)],
        distanceMeters: 95_000,
        durationSeconds: 3600,
        maneuvers: []
    )
    #expect(!TrafficRerouteCoordinator.isMeaningfullyBetterAlternate(alternate: marginal, original: original))

    let faster = ExternalRouteResponse(
        coordinates: [Coordinate(latitude: 51.5, longitude: -0.2)],
        distanceMeters: 98_000,
        durationSeconds: 3000,
        maneuvers: []
    )
    #expect(TrafficRerouteCoordinator.isMeaningfullyBetterAlternate(alternate: faster, original: original))
}

@Test func vehicleAdjustedClassifierIgnoresHgvLegalMotorwaySpeeds() {
    let flow = TomTomFlowSegmentData(
        currentSpeedKmh: 85,
        freeFlowSpeedKmh: 120,
        confidence: 0.9,
        roadClosed: false
    )
    let hgvSnapshot = VehicleAdjustedTrafficClassifier.snapshot(
        from: flow,
        vehicleClass: .heavyGoodsVehicle,
        measurementSystem: .imperial
    )
    #expect(hgvSnapshot.congestionLevel != .standstill)
    #expect(!VehicleAdjustedTrafficClassifier.isRerouteWorthy(flow: flow, snapshot: hgvSnapshot))

    let standstillFlow = TomTomFlowSegmentData(
        currentSpeedKmh: 5,
        freeFlowSpeedKmh: 90,
        confidence: 0.8,
        roadClosed: false
    )
    let standstillSnapshot = VehicleAdjustedTrafficClassifier.snapshot(
        from: standstillFlow,
        vehicleClass: .passengerCar,
        measurementSystem: .imperial
    )
    #expect(standstillSnapshot.congestionLevel == .standstill)
    #expect(VehicleAdjustedTrafficClassifier.isRerouteWorthy(flow: standstillFlow, snapshot: standstillSnapshot))
}

@Test func vehicleAdjustedClassifierRejectsLowConfidenceStandstill() {
    let flow = TomTomFlowSegmentData(
        currentSpeedKmh: 4,
        freeFlowSpeedKmh: 90,
        confidence: 0.2,
        roadClosed: false
    )
    let snapshot = VehicleAdjustedTrafficClassifier.snapshot(
        from: flow,
        vehicleClass: .passengerCar,
        measurementSystem: .imperial
    )
    #expect(!VehicleAdjustedTrafficClassifier.isRerouteWorthy(flow: flow, snapshot: snapshot))
}

@Test func openRouteServiceGeocoderIncludesLanguageQueryItem() {
    let items = OpenRouteServiceGeocoder.globalQueryItems(
        query: "Warsaw",
        near: Coordinate(latitude: 52.2, longitude: 21.0),
        limit: 8,
        language: "en"
    )
    #expect(items.contains { $0.name == "lang" && $0.value == "en" })
}
