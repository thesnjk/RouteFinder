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
}
