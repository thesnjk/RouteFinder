import Contracts
import DataLayer
import Foundation
import Testing
@testable import UI

@MainActor
@Suite("FleetDispatchCoordinator")
struct FleetDispatchCoordinatorTests {
    @Test func publishDispatchSnapshotUsesHostInputs() async {
        let host = MockFleetHost()
        host.activeDispatchTripId = UUID()
        let store = InMemoryFleetStore()
        let coordinator = FleetDispatchCoordinator(host: host, fleetStore: store)

        await coordinator.publishDispatchSnapshot(status: .active)

        #expect(host.lastPublishedFleetSnapshot?.status == .active)
        #expect(host.lastPublishedFleetSnapshot?.orderedStopIds.count == 2)
    }

    @Test func pollAppliesNewTripOnce() async {
        let host = MockFleetHost()
        let store = InMemoryFleetStore()
        let vehicle = FleetVehicle(orgId: UUID(), label: "Test")
        _ = try? await store.registerVehicle(vehicle)
        let trip = try! FleetTripBuilder.makeTrip(
            orgId: vehicle.orgId,
            vehicleId: vehicle.id,
            stops: [
                FleetTripStop(sequence: 0, label: "A", latitude: 52.6, longitude: 1.3, role: .origin),
                FleetTripStop(sequence: 1, label: "B", latitude: 52.7, longitude: 1.4, role: .destination),
            ]
        )
        _ = try? await store.pushTrip(trip)
        host.fleetVehicleId = vehicle.id
        host.fleetVehicleIdText = vehicle.id.uuidString

        let coordinator = FleetDispatchCoordinator(host: host, fleetStore: store)
        await coordinator.pollAndApplyFleetDispatch()
        #expect(host.appliedTrips.count == 1)
        await coordinator.pollAndApplyFleetDispatch()
        #expect(host.appliedTrips.count == 1)
    }
}

@MainActor
private final class MockFleetHost: FleetDispatchHost {
    var activeDispatchTripId: UUID?
    var fleetVehicleId: UUID?
    var fleetVehicleIdText = ""
    var fleetServerURLText = ""
    var fleetServerAPIKeyText = ""
    var useRemoteFleetServer = false
    var fleetServerConnectionStatus: String?
    var discoveredFleetServers: [DiscoveredFleetServer] = []
    var isDiscoveringFleetServers = false
    var fleetDiscoveryStatus: String?
    var fleetDispatchToast: String?
    var lastPublishedFleetSnapshot: FleetTripSnapshot?
    var appliedTrips: [FleetTrip] = []

    func applyDispatchedTrip(_ trip: FleetTrip) async {
        appliedTrips.append(trip)
        activeDispatchTripId = trip.id
    }

    func fleetSnapshotBuildInputs() -> FleetSnapshotBuildInputs? {
        guard let tripId = activeDispatchTripId else { return nil }
        return FleetSnapshotBuildInputs(
            tripId: tripId,
            orderedStopIds: [UUID(), UUID()],
            physicsETASeconds: 120,
            predictiveReport: nil,
            predictedLayby: nil,
            rehearsed: false
        )
    }
}
