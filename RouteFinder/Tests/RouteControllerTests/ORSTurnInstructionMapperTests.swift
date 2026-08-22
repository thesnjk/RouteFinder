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
    #expect(instructions.contains { $0.maneuver == .right })
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
