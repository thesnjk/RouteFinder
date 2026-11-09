import Contracts
import Foundation
import Testing
@testable import UI

@MainActor
@Test func invalidatePrepareAllowsOSMPrepareRefire() {
    let instructionID = UUID()
    let instruction = TurnInstruction(
        id: instructionID,
        maneuver: .left,
        roadName: "A11",
        distance: 350,
        bearing: 90,
        laneGuidance: LaneGuidance(
            lanes: [.left, .straight],
            recommendedIndices: [0],
            source: .osm
        )
    )
    let catalog = ManeuverAnchorCatalog(
        anchors: [
            ManeuverAnchor(
                id: instructionID,
                arcLengthAnchor: 1_000,
                roadName: "A11",
                maneuver: .left
            )
        ],
        cumulativeArcLengths: [0, 1_000]
    )
    let controller = ManeuverAnnouncementController()

    #expect(
        controller.shouldAnnounce(
            instruction: instruction,
            tier: .prepare,
            distanceToManeuverMeters: 350,
            catalog: catalog,
            currentArcLength: 650
        )
    )
    controller.recordSpoken(instructionID: instructionID, tier: .prepare)
    #expect(
        !controller.shouldAnnounce(
            instruction: instruction,
            tier: .prepare,
            distanceToManeuverMeters: 350,
            catalog: catalog,
            currentArcLength: 650
        )
    )

    controller.invalidatePrepareForLaneUpgrade(instructionID: instructionID)
    #expect(
        controller.shouldAnnounce(
            instruction: instruction,
            tier: .prepare,
            distanceToManeuverMeters: 350,
            catalog: catalog,
            currentArcLength: 650
        )
    )
}

@MainActor
@Test func invalidatePrepareNoOpsAfterExecute() {
    let instructionID = UUID()
    let instruction = TurnInstruction(
        id: instructionID,
        maneuver: .right,
        roadName: "A14",
        distance: 80,
        bearing: 45
    )
    let catalog = ManeuverAnchorCatalog(
        anchors: [
            ManeuverAnchor(
                id: instructionID,
                arcLengthAnchor: 500,
                roadName: "A14",
                maneuver: .right
            )
        ],
        cumulativeArcLengths: [0, 500]
    )
    let controller = ManeuverAnnouncementController()
    controller.recordSpoken(instructionID: instructionID, tier: .prepare)
    controller.recordSpoken(instructionID: instructionID, tier: .execute)
    controller.invalidatePrepareForLaneUpgrade(instructionID: instructionID)

    #expect(
        !controller.shouldAnnounce(
            instruction: instruction,
            tier: .prepare,
            distanceToManeuverMeters: 80,
            catalog: catalog,
            currentArcLength: 420
        )
    )
}

@Test func instructionIDsUpgradedToOSMDetectsHeuristicToOSM() {
    let id = UUID()
    let previous = [
        TurnInstruction(
            id: id,
            maneuver: .left,
            roadName: "A11",
            distance: 400,
            bearing: 10,
            laneGuidance: LaneGuidance(
                lanes: [.left, .straight],
                recommendedIndices: [0],
                source: .heuristic
            )
        )
    ]
    let updated = [
        TurnInstruction(
            id: id,
            maneuver: .left,
            roadName: "A11",
            distance: 400,
            bearing: 10,
            laneGuidance: LaneGuidance(
                lanes: [.left, .straight, .right],
                recommendedIndices: [0, 1],
                source: .osm
            )
        )
    ]
    #expect(
        ManeuverAnnouncementController.instructionIDsUpgradedToOSM(
            previous: previous,
            updated: updated
        ) == [id]
    )
}

@Test func instructionIDsUpgradedToOSMIgnoresAlreadyOSM() {
    let id = UUID()
    let guidance = LaneGuidance(
        lanes: [.right],
        recommendedIndices: [0],
        source: .osm
    )
    let previous = [
        TurnInstruction(
            id: id,
            maneuver: .right,
            roadName: nil,
            distance: 200,
            bearing: 0,
            laneGuidance: guidance
        )
    ]
    #expect(
        ManeuverAnnouncementController.instructionIDsUpgradedToOSM(
            previous: previous,
            updated: previous
        ).isEmpty
    )
}
