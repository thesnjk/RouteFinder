import Contracts
import Foundation
import Testing
@testable import UI

@Suite("DispatchFleetRoster")
struct DispatchFleetRosterTests {
    @Test func gpsAgeSecondsNilWithoutLocation() {
        let trip = FleetTrip(orgId: UUID(), vehicleId: UUID(), stops: [])
        #expect(DispatchFleetRoster.gpsAgeSeconds(trip: trip, now: Date()) == nil)
        #expect(DispatchFleetRoster.gpsAgeSeconds(trip: nil, now: Date()) == nil)
    }

    @Test func gpsAgeSecondsRoundsFromRecordedAt() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let trip = FleetTrip(
            orgId: UUID(),
            vehicleId: UUID(),
            stops: [],
            driverLatitude: 52.63,
            driverLongitude: 1.29,
            driverLocationRecordedAt: now.addingTimeInterval(-45)
        )
        #expect(DispatchFleetRoster.gpsAgeSeconds(trip: trip, now: now) == 45)
    }

    @Test func buildRowsPreservesOrderAndDefects() {
        let orgId = UUID()
        let v1 = FleetVehicle(orgId: orgId, label: "A", registrationPlate: "AA11 AAA")
        let v2 = FleetVehicle(orgId: orgId, label: "B")
        let defectTrip = FleetTrip(
            orgId: orgId,
            vehicleId: v1.id,
            status: .active,
            stops: [],
            latestInspectionSummary: TripBriefInspectionSummary(
                vehicleLabel: "A",
                registrationPlate: "AA11 AAA",
                defectCount: 2,
                completedAt: Date()
            ),
            driverLatitude: 52.0,
            driverLongitude: 1.0,
            driverLocationRecordedAt: Date()
        )
        let rows = DispatchFleetRoster.buildRows(
            vehicles: [v1, v2],
            tripByVehicleId: [v1.id: defectTrip, v2.id: nil],
            now: Date()
        )
        #expect(rows.count == 2)
        #expect(rows[0].vehicleId == v1.id)
        #expect(rows[0].hasDefects == true)
        #expect(rows[0].gpsAgeSeconds != nil)
        #expect(rows[1].vehicleId == v2.id)
        #expect(rows[1].trip == nil)
        #expect(DispatchFleetRoster.statusLabel(for: rows[1]) == "idle")
    }

    @Test func driverPinsSkipInvalidAndMissing() {
        let orgId = UUID()
        let withGPS = FleetVehicle(orgId: orgId, label: "Cab1")
        let noGPS = FleetVehicle(orgId: orgId, label: "Cab2")
        let trip = FleetTrip(
            orgId: orgId,
            vehicleId: withGPS.id,
            stops: [],
            driverLatitude: 52.63,
            driverLongitude: 1.29
        )
        let rows = DispatchFleetRoster.buildRows(
            vehicles: [withGPS, noGPS],
            tripByVehicleId: [
                withGPS.id: trip,
                noGPS.id: FleetTrip(orgId: orgId, vehicleId: noGPS.id, stops: []),
            ],
            now: Date()
        )
        let pins = DispatchFleetRoster.driverPins(from: rows)
        #expect(pins.count == 1)
        #expect(pins[0].vehicleId == withGPS.id)
        #expect(pins[0].label == "Cab1")
    }

    @Test func formatHelpers() {
        #expect(DispatchFleetRoster.formatPhysicsEta(seconds: 600) == "10 min")
        #expect(DispatchFleetRoster.formatPhysicsEta(seconds: nil) == "—")
        #expect(DispatchFleetRoster.formatGpsAge(30) == "30s")
        #expect(DispatchFleetRoster.formatGpsAge(120) == "2m")
        #expect(DispatchFleetRoster.formatGpsAge(nil) == "—")
        #expect(DispatchFleetRoster.vehicleCap == 20)
    }

    @Test func filterVehiclesEmptyQueryReturnsAll() {
        let orgId = UUID()
        let vehicles = [
            FleetVehicle(orgId: orgId, label: "Artic 1", registrationPlate: "AB12 CDE"),
            FleetVehicle(orgId: orgId, label: "Rigid 2"),
        ]
        #expect(DispatchFleetRoster.filterVehicles(vehicles, query: "").count == 2)
        #expect(DispatchFleetRoster.filterVehicles(vehicles, query: "   ").count == 2)
    }

    @Test func filterVehiclesMatchesLabelAndPlateCaseInsensitive() {
        let orgId = UUID()
        let artic = FleetVehicle(orgId: orgId, label: "Artic 1", registrationPlate: "AB12 CDE")
        let rigid = FleetVehicle(orgId: orgId, label: "Rigid 2", registrationPlate: "XY99 ZZZ")
        let all = [artic, rigid]

        let byLabel = DispatchFleetRoster.filterVehicles(all, query: "artic")
        #expect(byLabel.map(\.id) == [artic.id])

        let byPlate = DispatchFleetRoster.filterVehicles(all, query: "xy99")
        #expect(byPlate.map(\.id) == [rigid.id])

        #expect(DispatchFleetRoster.filterVehicles(all, query: "nope").isEmpty)
    }
}
