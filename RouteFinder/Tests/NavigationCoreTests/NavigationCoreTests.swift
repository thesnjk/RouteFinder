import Contracts
import CoreLocation
import NavigationCore
import Testing

@Test("Route polyline projector finds closest segment")
func routePolylineProjectorFindsSegment() {
    let coordinates = [
        Coordinate(latitude: 51.0, longitude: -1.0),
        Coordinate(latitude: 51.001, longitude: -1.0),
        Coordinate(latitude: 51.002, longitude: -1.0),
    ]
    let geometry = RouteGeometryCanonicalizer.process(coordinates, simulationStepMeters: 50)
    let projector = RoutePolylineProjector()
    let point = Coordinate(latitude: 51.001, longitude: -1.0001)
    let result = projector.project(
        point: point,
        spine: geometry,
        crossTrackThresholdMeters: 100
    )
    #expect(result != nil)
    #expect(result!.arcLengthMeters > 0)
}

@Test("Route geometry splitter produces traversed and remaining paths")
func routeGeometrySplitterSplitsAtArcLength() {
    let coords = [
        CLLocationCoordinate2D(latitude: 51.0, longitude: -1.0),
        CLLocationCoordinate2D(latitude: 51.01, longitude: -1.0),
        CLLocationCoordinate2D(latitude: 51.02, longitude: -1.0),
    ]
    let cumulative: [Double] = [0, 1111, 2222]
    let split = RouteGeometrySplitter.split(
        displayCoordinates: coords,
        cumulativeLengths: cumulative,
        splitArcLengthMeters: 1111
    )
    #expect(split.traversedPath.count >= 2)
    #expect(split.remainingPath.count >= 2)
    #expect(split.splitArcLengthMeters == 1111)
}

@Test("Route progress calculator computes remaining distance and ETA")
func routeProgressCalculatorComputesRemaining() {
    let calculator = RouteProgressCalculator()
    let snapshot = calculator.compute(
        arcLengthMeters: 500,
        totalLengthMeters: 1000,
        currentSpeedMps: 10,
        staticTotalTimeSeconds: 100
    )
    #expect(snapshot.remainingDistanceMeters == 500)
    #expect(snapshot.progressFraction == 0.5)
    #expect(snapshot.remainingETASeconds == 50)
}

@Test("Route progress calculator caps inflated static ETA with web routing baseline")
func routeProgressCalculatorCapsInflatedStaticETA() {
    let calculator = RouteProgressCalculator()
    let snapshot = calculator.compute(
        arcLengthMeters: 0,
        totalLengthMeters: 1000,
        currentSpeedMps: nil,
        staticTotalTimeSeconds: 600_000,
        webRoutingETASeconds: 100_000
    )
    #expect(snapshot.remainingETASeconds == 100_000)
}

@Test("Navigation session preserves turn instructions for voice lookup")
@MainActor
func navigationSessionTurnInstructionLookup() {
    let session = NavigationSession()
    let lane = LaneGuidance(lanes: [.left, .straight], recommendedIndices: [0])
    let instructions = [
        TurnInstruction(
            maneuver: .depart,
            roadName: "Start",
            distance: 500,
            bearing: 0
        ),
        TurnInstruction(
            maneuver: .left,
            roadName: "High Street",
            distance: 250,
            bearing: 270,
            laneGuidance: lane
        ),
        TurnInstruction(
            maneuver: .arrive,
            roadName: "End",
            distance: 0,
            bearing: 0
        ),
    ]
    let coordinates = [
        Coordinate(latitude: 51.0, longitude: -1.0),
        Coordinate(latitude: 51.01, longitude: -1.0),
    ]
    let canonical = RouteGeometryCanonicalizer.process(coordinates)
    session.loadRoute(canonical: canonical, turnInstructions: instructions)

    let leftID = instructions[1].id
    #expect(session.turnInstruction(withID: leftID)?.laneGuidance == lane)

    let enriched = [
        instructions[0],
        TurnInstruction(
            id: instructions[1].id,
            maneuver: .left,
            roadName: "High Street",
            distance: 250,
            bearing: 270,
            laneGuidance: LaneGuidance(lanes: [.straight, .right], recommendedIndices: [1])
        ),
        instructions[2],
    ]
    session.updateTurnInstructions(enriched)
    #expect(session.turnInstruction(withID: leftID)?.laneGuidance?.lanes == [.straight, .right])
}

@Test("Maneuver speech includes lane guidance at execute tier")
func maneuverSpeechIncludesLaneGuidance() {
    let instruction = TurnInstruction(
        maneuver: .right,
        roadName: "A47",
        distance: 120,
        bearing: 90,
        laneGuidance: LaneGuidance(lanes: [.straight, .right], recommendedIndices: [1])
    )
    let spoken = ManeuverSpeechFormatter.spokenPrompt(for: instruction, tier: .execute)
    #expect(spoken.contains(instruction.laneGuidance!.guidanceText))
    #expect(spoken.contains("Turn right"))
}
