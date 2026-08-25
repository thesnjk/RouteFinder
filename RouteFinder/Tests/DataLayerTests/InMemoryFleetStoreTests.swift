import Contracts
import DataLayer
import Foundation
import Testing

@Test func inMemoryFleetStorePushesThreeStopJobAndAcceptsSnapshot() async throws {
    let store = InMemoryFleetStore()
    let seeded = try await store.seedDemoThreeStopJob()
    #expect(seeded.trip.stops.count == 3)
    #expect(seeded.trip.status == .dispatched)

    let active = try await store.activeTrip(forVehicleId: seeded.vehicle.id)
    #expect(active?.id == seeded.trip.id)

    let reorderedIds = [
        seeded.trip.stops[0].id,
        seeded.trip.stops[2].id,
        seeded.trip.stops[1].id,
    ]
    let snapshot = FleetTripSnapshot(
        tripId: seeded.trip.id,
        status: .optimized,
        orderedStopIds: reorderedIds,
        physicsETASeconds: 12_600
    )
    let updated = try await store.applySnapshot(snapshot)
    #expect(updated.status == .optimized)
    #expect(updated.physicsETASeconds == 12_600)
    #expect(updated.stops.map(\.id) == reorderedIds)
}
