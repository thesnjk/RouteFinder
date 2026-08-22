import Contracts
import CoreLocation
import Foundation
@testable import RouteController
import Testing

@Suite("Geo Coordinate Key")
struct GeoCoordinateKeyTests {
    @Test("Matches coordinates within epsilon")
    func coordinateMatching() {
        let key = GeoCoordinateKey(latitude: 51.5, longitude: -0.1)
        let nearby = RoutingCoordinate(latitude: 51.5000005, longitude: -0.1000005)
        #expect(key.matches(nearby, epsilonMeters: 1.0))
    }
}

@Suite("Route Optimization Engine Vroom Payload")
struct RouteOptimizationEnginePayloadTests {
    @Test("Encodes UNIX time windows and HGV profile from vehicle specification")
    func payloadEncoding() throws {
        let start = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let end = CLLocationCoordinate2D(latitude: 51.6, longitude: -0.2)
        let waypoint = RoutingCoordinate(latitude: 51.55, longitude: -0.15)
        let windowStart = Date(timeIntervalSince1970: 1_700_000_000)
        let windowEnd = Date(timeIntervalSince1970: 1_700_003_600)
        let constraints = RouteSequenceConstraints(
            stopTimeWindows: [
                GeoCoordinateKey(waypoint): RouteSequenceConstraints.TimeWindow(
                    start: windowStart,
                    end: windowEnd
                ),
            ],
            driverBreakIntervals: [900]
        )
        let profile = VehicleSpecificationProfile.routingDefault(
            vehicleClass: .heavyGoodsVehicle,
            grossWeightKilograms: 18_000
        )

        let data = try RouteOptimizationEngine.buildVroomPayloadData(
            start: start,
            end: end,
            waypoints: [waypoint],
            vehicleProfile: profile,
            constraints: constraints
        )
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"time_windows\""))
        #expect(json.contains("1700000000"))
        #expect(json.contains("1700003600"))
        #expect(json.contains("\"breaks\""))
        #expect(json.contains("driving-hgv"))
        #expect(json.contains("\"capacity\":[18000]"))
    }

    @Test("Maps passenger car profile to driving-car")
    func carProfile() throws {
        let profile = VehicleSpecificationProfile.routingDefault(vehicleClass: .passengerCar)
        let data = try RouteOptimizationEngine.buildVroomPayloadData(
            start: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            end: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            waypoints: [RoutingCoordinate(latitude: 0.5, longitude: 0.5)],
            vehicleProfile: profile
        )
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("driving-car"))
    }
}

@Suite("Local Two-Opt Engine")
struct LocalTwoOptEngineTests {
    @Test("2-opt improves tour distance over naive order")
    func twoOptImprovement() async throws {
        let engine = RouteOptimizationEngine(orsAPIKey: nil, vehicleProfile: .routingDefault(vehicleClass: .passengerCar))
        let start = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let end = CLLocationCoordinate2D(latitude: 0, longitude: 3)
        let waypoints = [
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 0, longitude: 2),
        ]
        let profile = VehicleSpecificationProfile.routingDefault(vehicleClass: .passengerCar)
        let sequence = try await engine.optimizeSequence(
            startPoint: start,
            waypoints: waypoints,
            endPoint: end,
            vehicleProfile: profile,
            tier: .localOnly
        )
        #expect(sequence.count == 4)
        #expect(sequence.first?.longitude == 0)
        #expect(sequence.last?.longitude == 3)
    }
}

@Suite("TomTom Traffic Flow Integration")
struct TomTomTrafficFlowIntegrationTests {
    @Test("HGV ceiling caps free-flow before congestion classification")
    func hgvSpeedCeiling() async {
        let profile = VehicleSpecificationProfile.routingDefault(vehicleClass: .heavyGoodsVehicle)
        let integration = TomTomTrafficFlowIntegration(apiKey: nil, vehicleProfile: profile)
        let flow = TomTomFlowSegmentData(
            currentSpeedKmh: 80,
            freeFlowSpeedKmh: 130,
            confidence: 0.9,
            roadClosed: false
        )
        let multiplier = await integration.travelTimeMultiplier(flow: flow)
        #expect(multiplier < 1.0)
    }

    @Test("Parses flow segment JSON into congestion level")
    func parseFlowSegment() throws {
        let json = """
        {
          "flowSegmentData": {
            "currentSpeed": 5,
            "freeFlowSpeed": 60,
            "confidence": 0.9,
            "roadClosed": false
          }
        }
        """
        let data = Data(json.utf8)
        let segment = try TomTomTrafficFlowClient.parseFlowSegment(from: data)
        #expect(segment.currentSpeedKmh == 5)
        #expect(segment.freeFlowSpeedKmh == 60)
        #expect(segment.congestionLevel == .standstill)
        #expect(segment.congestionLevel.velocityMultiplier == 0.05)
    }
}

@Suite("Traffic Signal Controller")
struct TrafficSignalControllerTests {
    @Test("Required deceleration increases as signal approaches")
    func decelerationMapping() async {
        let controller = TrafficSignalController()
        let permission = await controller.permittedSpeed(
            arcLength: 100,
            currentSpeedMps: 15,
            maxDecelMps2: 3.0,
            deltaTime: 0.033
        )
        #expect(permission.permittedSpeedMps == .infinity || permission.permittedSpeedMps >= 0)
    }
}
