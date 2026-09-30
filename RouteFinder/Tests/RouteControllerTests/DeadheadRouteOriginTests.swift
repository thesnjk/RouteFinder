import Contracts
import RouteController
import Testing

@Suite("DeadheadRouteOrigin")
struct DeadheadRouteOriginTests {
    private let pickup = RoutingCoordinate(latitude: 51.9542, longitude: 1.3511)
    private let via = RoutingCoordinate(latitude: 52.4862, longitude: -1.8904)
    private let destination = RoutingCoordinate(latitude: 53.4808, longitude: -2.2426)
    /// ~few metres from Felixstowe pickup.
    private let cabNearPickup = RoutingCoordinate(latitude: 51.9543, longitude: 1.3512)
    /// Norwich-ish — well beyond 250 m from Felixstowe.
    private let cabFar = RoutingCoordinate(latitude: 52.6309, longitude: 1.2974)

    @Test func farCabPrependsJobOriginAsVia() {
        let legs = DeadheadRouteOrigin.resolve(
            jobOrigin: pickup,
            jobVias: [via],
            jobDestination: destination,
            cabCoordinate: cabFar,
            deadheadEnabled: true
        )
        #expect(legs.appliedDeadhead == true)
        #expect(legs.origin == cabFar)
        #expect(legs.waypoints == [pickup, via])
        #expect(legs.destination == destination)
    }

    @Test func nearCabLeavesJobOriginUnchanged() {
        let legs = DeadheadRouteOrigin.resolve(
            jobOrigin: pickup,
            jobVias: [via],
            jobDestination: destination,
            cabCoordinate: cabNearPickup,
            deadheadEnabled: true
        )
        #expect(legs.appliedDeadhead == false)
        #expect(legs.origin == pickup)
        #expect(legs.waypoints == [via])
        #expect(legs.destination == destination)
    }

    @Test func disabledOrMissingCabSkipsDeadhead() {
        let noCab = DeadheadRouteOrigin.resolve(
            jobOrigin: pickup,
            jobVias: [],
            jobDestination: destination,
            cabCoordinate: nil,
            deadheadEnabled: true
        )
        #expect(noCab.appliedDeadhead == false)
        #expect(noCab.origin == pickup)

        let disabled = DeadheadRouteOrigin.resolve(
            jobOrigin: pickup,
            jobVias: [],
            jobDestination: destination,
            cabCoordinate: cabFar,
            deadheadEnabled: false
        )
        #expect(disabled.appliedDeadhead == false)
        #expect(disabled.origin == pickup)
    }
}
