import Contracts
import CoreLocation
import RouteController
import Testing

struct TurnLanesParserTests {
    @Test func parseStandardTurnLanes() {
        let guidance = TurnLanesParser.parse(turnLanes: "left|through|right")
        #expect(guidance != nil)
        #expect(guidance?.lanes.count == 3)
        #expect(guidance?.lanes[0] == .left)
        #expect(guidance?.lanes[1] == .straight)
        #expect(guidance?.lanes[2] == .right)
        #expect(guidance?.recommendedIndices.contains(1) == true)
    }

    @Test func parseMergeTokens() {
        let guidance = TurnLanesParser.parse(turnLanes: "merge_to_left|through|merge_to_right")
        #expect(guidance?.lanes == [.merge, .straight, .merge])
    }

    @Test func heuristicHighlightsEdgeLanes() {
        let left = TurnLanesParser.heuristic(for: .left)
        #expect(left.recommendedIndices == [0])

        let right = TurnLanesParser.heuristic(for: .right)
        #expect(right.recommendedIndices == [right.lanes.count - 1])
    }

    @Test func laneGuidanceVoiceText() {
        let guidance = LaneGuidance(lanes: [.left, .straight, .right], recommendedIndices: [0])
        #expect(guidance.guidanceText == "Use the left lane")
    }

    @Test func parseCompoundLanesForLeftManeuver() {
        let guidance = TurnLanesParser.parse(
            turnLanes: "left;through|through|through;right",
            forManeuver: .left
        )
        #expect(guidance?.lanes[0] == .left)
        #expect(guidance?.recommendedIndices == [0])
    }

    @Test func parseSkipsNoneLaneForLeftManeuver() {
        let guidance = TurnLanesParser.parse(
            turnLanes: "none|left|through",
            forManeuver: .left
        )
        #expect(guidance?.recommendedIndices == [1])
    }

    @Test func parseCompoundLaneForStraightManeuver() {
        let guidance = TurnLanesParser.parse(
            turnLanes: "left;through",
            forManeuver: .straight
        )
        #expect(guidance?.lanes[0] == .straight)
        #expect(guidance?.recommendedIndices == [0])
    }
}

struct VehicleFootprintPartsTests {
    @Test func hgvProducesCabAndTrailerParts() {
        let rearAxle = CLLocationCoordinate2D(latitude: 52.63, longitude: 1.297)
        let parts = VehicleGeometryCalculator.generateFootprintParts(
            rearAxle: rearAxle,
            headingDegrees: 0,
            lengthMeters: 16.5,
            widthMeters: 2.55,
            isPassengerCar: false
        )
        #expect(parts.count == 2)
        #expect(parts[0].count >= 5)
        #expect(parts[1].count >= 5)
    }

    @Test func passengerCarUsesSinglePart() {
        let rearAxle = CLLocationCoordinate2D(latitude: 52.63, longitude: 1.297)
        let parts = VehicleGeometryCalculator.generateFootprintParts(
            rearAxle: rearAxle,
            headingDegrees: 90,
            lengthMeters: 4.5,
            widthMeters: 1.8,
            isPassengerCar: true
        )
        #expect(parts.count == 1)
    }
}
