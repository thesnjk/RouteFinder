import Contracts
import Foundation
import RouteController
import Testing

@Test func orsTurnInstructionMapperDepartAndArrive() {
    let maneuvers = [
        ExternalManeuver(
            instruction: "Head north on High Street",
            distanceMeters: 120,
            durationSeconds: 30,
            stepType: 1
        ),
        ExternalManeuver(
            instruction: "Turn right onto Market Road",
            distanceMeters: 450,
            durationSeconds: 90,
            stepType: 10
        ),
        ExternalManeuver(
            instruction: "Arrive at destination",
            distanceMeters: 0,
            durationSeconds: 0,
            stepType: 100
        ),
    ]

    let coordinates = [
        Coordinate(latitude: 51.50, longitude: -0.10),
        Coordinate(latitude: 51.501, longitude: -0.10),
        Coordinate(latitude: 51.501, longitude: -0.099),
        Coordinate(latitude: 51.502, longitude: -0.099),
    ]

    let instructions = ORSTurnInstructionMapper.map(maneuvers: maneuvers, coordinates: coordinates)

    #expect(!instructions.isEmpty)
    #expect(instructions.first?.maneuver == .depart)
    #expect(instructions.first?.roadName == nil)
    #expect(instructions.contains { $0.maneuver == .right && $0.roadName == "Market Road" })
    #expect(instructions.last?.maneuver == .arrive)
}

@Test func polylineTurnInstructionFallback() {
    let coordinates = [
        Coordinate(latitude: 51.50, longitude: -0.10),
        Coordinate(latitude: 51.501, longitude: -0.10),
        Coordinate(latitude: 51.501, longitude: -0.099),
        Coordinate(latitude: 51.502, longitude: -0.099),
    ]

    let instructions = PolylineTurnInstructionGenerator.generate(coordinates: coordinates)

    #expect(instructions.first?.maneuver == .depart)
    #expect(instructions.last?.maneuver == .arrive)
    #expect(instructions.count >= 2)
}

@Test func externalRoutePopulatesTurnInstructions() async throws {
    struct FixtureClient: ExternalRoutingClient {
        func route(request: ExternalRouteRequest) async throws -> ExternalRouteResponse {
            ExternalRouteResponse(
                coordinates: [
                    Coordinate(latitude: 51.50, longitude: -0.10),
                    Coordinate(latitude: 51.501, longitude: -0.10),
                    Coordinate(latitude: 51.501, longitude: -0.099),
                ],
                distanceMeters: 250,
                durationSeconds: 60,
                maneuvers: [
                    ExternalManeuver(
                        instruction: "Head north",
                        distanceMeters: 120,
                        durationSeconds: 30,
                        stepType: 1
                    ),
                    ExternalManeuver(
                        instruction: "Turn right",
                        distanceMeters: 130,
                        durationSeconds: 30,
                        stepType: 10
                    ),
                ]
            )
        }
    }

    let planner = RoutePlanner(externalClient: FixtureClient())
    let request = ExternalRouteRequest(
        origin: RoutingCoordinate(latitude: 51.50, longitude: -0.10),
        destination: RoutingCoordinate(latitude: 51.501, longitude: -0.099),
        vehicle: .default,
        preferences: RoutingPreferences()
    )

    let (result, _) = try await planner.calculateExternalRoute(request: request)
    #expect(!result.turnInstructions.isEmpty)
    #expect(result.turnInstructions.first?.maneuver == .depart)
}

struct ORSRoadNameExtractionTests {
    @Test func extractsOntoRoadName() {
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "Turn right onto Market Road")
                == "Market Road"
        )
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "Slight left onto the A47")
                == "the A47"
        )
    }

    @Test func extractsOnAndTowardRoadNames() {
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "Continue on High Street")
                == "High Street"
        )
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "Keep left toward Norwich")
                == "Norwich"
        )
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "Bear right towards the A11")
                == "the A11"
        )
    }

    @Test func ignoresHeadAndArriveInstructions() {
        #expect(ORSTurnInstructionMapper.extractedRoadName(from: "Head northeast on A47") == nil)
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(from: "You have arrived at your destination")
                == nil
        )
    }

    @Test func stripsTrailingAndClause() {
        #expect(
            ORSTurnInstructionMapper.extractedRoadName(
                from: "Turn left onto Station Road and continue"
            ) == "Station Road"
        )
    }
}
