import Contracts
import DataLayer
import Foundation
import Testing

@Test func vehiclesForOrgIdFiltersByOrg() async throws {
    let store = InMemoryFleetStore()
    let orgA = try await store.createOrg(name: "Org A")
    let orgB = try await store.createOrg(name: "Org B")
    let vehicleA = try await store.registerVehicle(
        FleetVehicle(orgId: orgA.id, label: "Truck A", registrationPlate: "AA11 AAA")
    )
    _ = try await store.registerVehicle(
        FleetVehicle(orgId: orgB.id, label: "Truck B", registrationPlate: "BB22 BBB")
    )

    let vehicles = try await store.vehicles(forOrgId: orgA.id)
    #expect(vehicles.count == 1)
    #expect(vehicles.first?.id == vehicleA.id)
}

@Test func applySnapshotCopiesPredictedLaybyOntoTrip() async throws {
    let store = InMemoryFleetStore()
    let seeded = try await store.seedDemoThreeStopJob()
    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "demo-layby",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "M1 J15 Layby"
        ),
        distanceRemainingMeters: 12_000,
        estimatedArrivalSeconds: 3_600,
        confidence: 0.82,
        occupancyPrior: .low,
        breakWindowOpensAt: Date(timeIntervalSince1970: 1_700_000_000),
        reasonCodes: [.physicsStress],
        isAdvisory: true
    )
    let snapshot = FleetTripSnapshot(
        tripId: seeded.trip.id,
        status: .rehearsed,
        orderedStopIds: seeded.trip.stops.map(\.id),
        physicsETASeconds: 9_900,
        predictedLayby: layby
    )

    let updated = try await store.applySnapshot(snapshot)
    #expect(updated.predictedLayby?.stop.id == "demo-layby")
    #expect(updated.predictedLayby?.stop.label == "M1 J15 Layby")
}

@Test func applySnapshotMergesDriverGPSOntoTrip() async throws {
    let store = InMemoryFleetStore()
    let seeded = try await store.seedDemoThreeStopJob()
    let recordedAt = Date(timeIntervalSince1970: 1_720_000_000)
    let snapshot = FleetTripSnapshot(
        tripId: seeded.trip.id,
        status: .active,
        orderedStopIds: seeded.trip.stops.map(\.id),
        physicsETASeconds: 7_200,
        driverLatitude: 52.6309,
        driverLongitude: 1.2974,
        driverLocationRecordedAt: recordedAt
    )

    let updated = try await store.applySnapshot(snapshot)
    #expect(updated.driverLatitude == 52.6309)
    #expect(updated.driverLongitude == 1.2974)
    #expect(updated.driverLocationRecordedAt == recordedAt)
}

@Test func fleetTripSnapshotGPSRoundTripsThroughJSON() throws {
    let tripId = UUID()
    let stopId = UUID()
    let recordedAt = Date(timeIntervalSince1970: 1_720_000_123)
    let snapshot = FleetTripSnapshot(
        tripId: tripId,
        status: .active,
        orderedStopIds: [stopId],
        physicsETASeconds: 1_200,
        driverLatitude: 52.75,
        driverLongitude: 0.39,
        driverLocationRecordedAt: recordedAt
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(FleetTripSnapshot.self, from: data)
    #expect(decoded.tripId == tripId)
    #expect(decoded.driverLatitude == 52.75)
    #expect(decoded.driverLongitude == 0.39)
    #expect(abs(decoded.driverLocationRecordedAt!.timeIntervalSince1970 - recordedAt.timeIntervalSince1970) < 1)
    #expect(decoded.orderedStopIds == [stopId])
}

@Test func createAndPushTripAssignsStopRoles() async throws {
    let store = InMemoryFleetStore()
    let org = try await store.createOrg(name: "Dispatch Test Ltd")
    let vehicle = try await store.registerVehicle(
        FleetVehicle(orgId: org.id, label: "Artic", registrationPlate: "RF01 DIS")
    )
    let stops = [
        FleetTripStop(sequence: 0, label: "Felixstowe", latitude: 51.95, longitude: 1.35, role: .via),
        FleetTripStop(sequence: 1, label: "Midlands", latitude: 52.48, longitude: -1.90, role: .via),
        FleetTripStop(sequence: 2, label: "Manchester", latitude: 53.48, longitude: -2.24, role: .via),
    ]

    let trip = try await store.createAndPushTrip(
        orgId: org.id,
        vehicleId: vehicle.id,
        stops: stops,
        companyBreaks: [CompanyBreakAllocation.demoAfternoonBreak()]
    )

    #expect(trip.stops.count == 3)
    #expect(trip.stops[0].role == .origin)
    #expect(trip.stops[1].role == .via)
    #expect(trip.stops[2].role == .destination)
    #expect(trip.companyBreaks.count == 1)
    #expect(trip.status == .dispatched)
}

@Test func dispatchRoutePreviewBuilderMapsDraftCoordinates() {
    let draft = DispatchTripDraft.ukDemoTemplate()
    let coords = DispatchRoutePreviewBuilder.straightLineCoordinates(from: draft)
    #expect(coords.count == 3)
    #expect(coords.first?.latitude == 51.9542)
}

@Test func norfolkDemoCorridorMatchesWebBuildDemoTripCoords() throws {
    let draft = DispatchTripDraft.norfolkDemoCorridor()
    #expect(draft.stops.count == 2)
    #expect(draft.stops[0].label == "Norwich")
    #expect(draft.stops[0].latitude == "52.6309")
    #expect(draft.stops[0].longitude == "1.2974")
    #expect(draft.stops[1].label == "King's Lynn")
    #expect(draft.stops[1].latitude == "52.7519")
    #expect(draft.stops[1].longitude == "0.3955")
    let fleetStops = try draft.fleetStops()
    #expect(fleetStops[0].role == .origin)
    #expect(fleetStops[1].role == .destination)
}

@Test func dispatchRoutePreviewBuilderRequiresParseableCoordinates() {
    var draft = DispatchTripDraft()
    draft.stops = [
        DispatchStopDraft(label: "A", latitude: "bad", longitude: "1.0"),
        DispatchStopDraft(label: "B", latitude: "52.0", longitude: "also-bad"),
    ]
    #expect(DispatchRoutePreviewBuilder.straightLineCoordinates(from: draft).isEmpty)
}
