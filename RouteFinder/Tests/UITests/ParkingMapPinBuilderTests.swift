import Contracts
import CostModel
import Foundation
import Testing
@testable import UI

struct ParkingMapPinBuilderTests {
    @Test func mapsParkingTiersToPinKinds() {
        #expect(RoutePin.pinKind(for: .ample) == RoutePin.PinKind.parkingAmple)
        #expect(RoutePin.pinKind(for: .limited) == RoutePin.PinKind.parkingLimited)
        #expect(RoutePin.pinKind(for: .full) == RoutePin.PinKind.parkingFull)
    }

    @Test func buildsPinsForParkingAndLaybyOnly() {
        let pois = [
            TruckPoi(
                id: "fuel",
                kind: .highFlowDiesel,
                latitude: 51.50,
                longitude: -0.10,
                label: "Fuel",
                arcLengthAlongRouteMeters: 1_000,
                confidence: 0.9
            ),
            TruckPoi(
                id: "layby-a",
                kind: .layby,
                latitude: 51.51,
                longitude: -0.11,
                label: "Layby A",
                arcLengthAlongRouteMeters: 3_000,
                confidence: 0.8
            ),
            TruckPoi(
                id: "secure",
                kind: .overnightSecureParking,
                latitude: 51.52,
                longitude: -0.12,
                label: "Secure Yard",
                arcLengthAlongRouteMeters: 5_000,
                confidence: 0.95
            ),
        ]
        let pins = ParkingMapPinBuilder.pins(from: pois, maxPins: 8)
        #expect(pins.count == 2)
        #expect(pins[0].id == "parking-layby-a")
        let parkingKinds: Set<RoutePin.PinKind> = [
            .parkingAmple,
            .parkingLimited,
            .parkingFull,
        ]
        #expect(parkingKinds.contains(pins[0].kind))
        #expect(pins[1].id == "parking-secure")
        #expect(abs(pins[0].coordinate.latitude - 51.51) < 0.0001)
    }

    @Test func emptyPoisYieldNoPins() {
        #expect(ParkingMapPinBuilder.pins(from: []).isEmpty)
    }

    @Test func respectsMaxPinsCap() {
        let pois = (0..<12).map { index in
            TruckPoi(
                id: "layby-\(index)",
                kind: .layby,
                latitude: 51.5 + Double(index) * 0.01,
                longitude: -0.1,
                label: "Layby \(index)",
                arcLengthAlongRouteMeters: Double(index + 1) * 1_000,
                confidence: 0.8
            )
        }
        let pins = ParkingMapPinBuilder.pins(from: pois, maxPins: 8)
        #expect(pins.count == 8)
        #expect(pins.first?.id == "parking-layby-0")
        #expect(pins.last?.id == "parking-layby-7")
    }

    @Test func highConfidenceSecureMapsToAmple() {
        let poi = TruckPoi(
            id: "yard",
            kind: .overnightSecureParking,
            latitude: 52.0,
            longitude: -1.0,
            label: "Yard",
            arcLengthAlongRouteMeters: 2_000,
            confidence: 0.95
        )
        // Midday (hour 12) avoids evening peak multiplier crushing ample band.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        let pins = ParkingMapPinBuilder.pins(from: [poi], asOf: date)
        #expect(pins.count == 1)
        #expect(pins[0].kind == RoutePin.PinKind.parkingAmple)
    }

    @Test func buildsPinsFromRankedAdvisoriesByOccupancyPrior() {
        let advisories = [
            LaybyAdvisory(
                stop: LaybyStop(
                    id: "a",
                    coordinate: Coordinate(latitude: 52.63, longitude: 1.29),
                    label: "Ample Layby"
                ),
                distanceRemainingMeters: 1_000,
                occupancyPrior: .low
            ),
            LaybyAdvisory(
                stop: LaybyStop(
                    id: "b",
                    coordinate: Coordinate(latitude: 52.64, longitude: 1.30),
                    label: "Limited Layby"
                ),
                distanceRemainingMeters: 2_000,
                occupancyPrior: .moderate
            ),
            LaybyAdvisory(
                stop: LaybyStop(
                    id: "c",
                    coordinate: Coordinate(latitude: 52.65, longitude: 1.31),
                    label: "Full Layby"
                ),
                distanceRemainingMeters: 3_000,
                occupancyPrior: .high
            ),
        ]
        let pins = ParkingMapPinBuilder.pins(from: advisories, maxPins: 8)
        #expect(pins.count == 3)
        #expect(pins[0].id == "parking-layby-a")
        #expect(pins[0].kind == .parkingAmple)
        #expect(pins[0].title.contains("Spaces"))
        #expect(pins[1].kind == .parkingLimited)
        #expect(pins[2].kind == .parkingFull)
    }

    @Test func rankedAdvisoryPinsRespectMaxCap() {
        let advisories = (0..<12).map { index in
            LaybyAdvisory(
                stop: LaybyStop(
                    id: "r-\(index)",
                    coordinate: Coordinate(latitude: 52.0 + Double(index) * 0.01, longitude: 1.0),
                    label: "Ranked \(index)"
                ),
                distanceRemainingMeters: Double(index + 1) * 500,
                occupancyPrior: .moderate
            )
        }
        let pins = ParkingMapPinBuilder.pins(from: advisories, maxPins: 8)
        #expect(pins.count == 8)
        #expect(pins.first?.id == "parking-layby-r-0")
        #expect(pins.last?.id == "parking-layby-r-7")
    }

    @Test func emptyAdvisoriesYieldNoPins() {
        #expect(ParkingMapPinBuilder.pins(from: [LaybyAdvisory]()).isEmpty)
    }

    @Test func mergedPinsPreferAdvisoryOverNearbyPoi() {
        let advisory = LaybyAdvisory(
            stop: LaybyStop(
                id: "same",
                coordinate: Coordinate(latitude: 52.6309, longitude: 1.2974),
                label: "Ranked Same"
            ),
            distanceRemainingMeters: 800,
            occupancyPrior: .low
        )
        let nearbyPoi = TruckPoi(
            id: "poi-same",
            kind: .layby,
            latitude: 52.63091,
            longitude: 1.29741,
            label: "POI Same",
            arcLengthAlongRouteMeters: 800,
            confidence: 0.5
        )
        let farPoi = TruckPoi(
            id: "poi-far",
            kind: .overnightSecureParking,
            latitude: 52.70,
            longitude: 1.40,
            label: "Far Yard",
            arcLengthAlongRouteMeters: 8_000,
            confidence: 0.9
        )
        let pins = ParkingMapPinBuilder.mergedParkingPins(
            advisories: [advisory],
            pois: [nearbyPoi, farPoi],
            maxPins: 8
        )
        #expect(pins.count == 2)
        #expect(pins[0].id == "parking-layby-same")
        #expect(pins[0].kind == .parkingAmple)
        #expect(pins[1].id == "parking-poi-far")
    }
}
