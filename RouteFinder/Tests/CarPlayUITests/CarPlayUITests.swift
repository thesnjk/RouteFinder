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

@Test func carPlayManeuverFactoryMapsTurnInstruction() {
    let instruction = TurnInstruction(
        maneuver: .left,
        roadName: "High Street",
        distance: 250,
        bearing: 270
    )
    let maneuver = CarPlayTemplateFactory.makeManeuver(from: instruction)
    #expect(maneuver.instructionVariants.first?.contains("High Street") == true)
}
#else
import Testing

@Test func carPlayTestsRequireIOS() {
    #expect(Bool(true))
}
#endif
