import Contracts
import CostModel
import Foundation
import Testing

@Test func parkingOccupancyPriorLowersEveningConfidence() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 19
    components.minute = 0
    let evening = calendar.date(from: components)!

    let poi = TruckPoi(
        id: "yard-1",
        kind: .overnightSecureParking,
        latitude: 51.5,
        longitude: -0.1,
        label: "Secure yard",
        confidence: 0.9
    )

    let adjusted = ParkingOccupancyPrior.adjust(
        pois: [poi],
        reports: [],
        date: evening,
        calendar: calendar
    )
    let confidence = try! #require(adjusted.first?.confidence)
    #expect(confidence < 0.9)
    #expect(abs(confidence - 0.9 * ParkingOccupancyPrior.eveningPeakMultiplier) < 0.001)
}

@Test func parkingOccupancyPriorLeavesFuelUnchangedAtEvening() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 19
    let evening = calendar.date(from: components)!

    let fuel = TruckPoi(
        id: "fuel-1",
        kind: .highFlowDiesel,
        latitude: 51.5,
        longitude: -0.1,
        label: "Fuel",
        confidence: 0.85
    )
    let adjusted = ParkingOccupancyPrior.adjust(
        pois: [fuel],
        reports: [],
        date: evening,
        calendar: calendar
    )
    #expect(adjusted.first?.confidence == 0.85)
}
