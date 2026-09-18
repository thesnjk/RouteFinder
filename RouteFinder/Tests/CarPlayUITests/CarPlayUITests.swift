#if os(iOS)
import CarPlay
import Contracts
import CoreLocation
import Testing
@testable import CarPlayUI

@Test func carPlayTemplateFactoryIncludesRouteChoiceOnTrip() {
    let origin = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
    let destination = CLLocationCoordinate2D(latitude: 52.0, longitude: 0.5)
    let routeChoice = CarPlayTemplateFactory.makeRouteChoice(
        name: "Test Route",
        distanceMeters: 42_000,
        timeSeconds: 2_400
    )
    let trip = CarPlayTemplateFactory.makeTrip(
        origin: origin,
        destination: destination,
        routeChoices: [routeChoice]
    )

    #expect(trip.routeChoices.count == 1)
}

@Test func makeTripUsesCustomEndpointNames() {
    let origin = CLLocationCoordinate2D(latitude: 52.63, longitude: 1.30)
    let destination = CLLocationCoordinate2D(latitude: 52.75, longitude: 0.40)
    let routeChoice = CarPlayTemplateFactory.makeRouteChoice(
        name: "Norwich → King's Lynn",
        distanceMeters: 70_000,
        timeSeconds: 3_600
    )
    let trip = CarPlayTemplateFactory.makeTrip(
        origin: origin,
        destination: destination,
        routeChoices: [routeChoice],
        originName: "Norwich",
        destinationName: "King's Lynn"
    )

    #expect(trip.origin.name == "Norwich")
    #expect(trip.destination.name == "King's Lynn")
    #expect(trip.routeChoices.count == 1)
}

@Test func carPlayManeuverFactoryMapsTurnInstruction() {
    let instruction = TurnInstruction(
        maneuver: .left,
        roadName: "High Street",
        distance: 250,
        bearing: 270
    )
    let maneuver = CarPlayTemplateFactory.makeManeuver(
        from: instruction,
        remainingETASeconds: 600,
        remainingDistanceMeters: 5_000
    )
    #expect(maneuver.instructionVariants.first?.contains("High Street") == true)
    let spoken = ManeuverSpeechFormatter.spokenPrompt(for: instruction, tier: .execute)
    #expect(spoken.lowercased().contains("left"))
    #expect(maneuver.initialTravelEstimates?.timeRemaining ?? 0 > 0)
}
#else
import Testing

@Test func carPlayTestsRequireIOS() {
    #expect(Bool(true))
}
#endif
