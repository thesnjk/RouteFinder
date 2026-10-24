import Contracts
import CostModel
import Foundation
import Testing

struct ParkingAvailabilityTierTests {
    @Test func occupancyPriorInvertsToAvailability() {
        #expect(ParkingAvailabilityTier(occupancyPrior: .low) == .ample)
        #expect(ParkingAvailabilityTier(occupancyPrior: .moderate) == .limited)
        #expect(ParkingAvailabilityTier(occupancyPrior: .high) == .full)
    }

    @Test func confidenceBandsMapToTiers() {
        #expect(ParkingAvailabilityTier(confidence: 0.9) == .ample)
        #expect(ParkingAvailabilityTier(confidence: 0.72) == .ample)
        #expect(ParkingAvailabilityTier(confidence: 0.55) == .limited)
        #expect(ParkingAvailabilityTier(confidence: 0.48) == .limited)
        #expect(ParkingAvailabilityTier(confidence: 0.3) == .full)
    }

    @Test func fuelAndWeighReturnNilTier() {
        let fuel = TruckPoi(
            id: "fuel",
            kind: .highFlowDiesel,
            latitude: 51.5,
            longitude: -0.1,
            label: "Fuel",
            confidence: 0.9
        )
        #expect(ParkingOccupancyPrior.availabilityTier(for: fuel) == nil)

        let weigh = TruckPoi(
            id: "weigh",
            kind: .weighStation,
            latitude: 51.5,
            longitude: -0.1,
            label: "Weigh",
            confidence: 0.9
        )
        #expect(ParkingOccupancyPrior.availabilityTier(for: weigh) == nil)
    }

    @Test func secureParkingEveningPeakIsNotAmple() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 1
        components.hour = 19
        let evening = calendar.date(from: components)!

        let poi = TruckPoi(
            id: "yard-1",
            kind: .overnightSecureParking,
            latitude: 51.5,
            longitude: -0.1,
            label: "Secure yard",
            confidence: 0.9
        )
        let tier = ParkingOccupancyPrior.availabilityTier(
            for: poi,
            reports: [],
            asOf: evening,
            calendar: calendar
        )
        // 0.9 * 0.65 = 0.585 → limited
        #expect(tier == .limited)
    }

    @Test func laybyCrowdFullReportMapsToFull() {
        let poi = TruckPoi(
            id: "layby-1",
            kind: .layby,
            latitude: 52.0,
            longitude: 0.1,
            label: "A11 Layby",
            confidence: 0.9
        )
        let report = CrowdReport(
            latitude: 52.0,
            longitude: 0.1,
            type: .laybyFull,
            reporterId: "driver-1",
            createdAt: Date(),
            note: "layby-1"
        )
        let tier = ParkingOccupancyPrior.availabilityTier(
            for: poi,
            reports: [report],
            asOf: Date()
        )
        #expect(tier == .full)
    }

    @Test func laybyCrowdSpacesReportMapsToAmple() {
        let poi = TruckPoi(
            id: "layby-2",
            kind: .layby,
            latitude: 52.1,
            longitude: 0.2,
            label: "A14 Layby",
            confidence: 0.5
        )
        let report = CrowdReport(
            latitude: 52.1,
            longitude: 0.2,
            type: .laybySpaces,
            reporterId: "driver-2",
            createdAt: Date(),
            note: "layby-2"
        )
        let tier = ParkingOccupancyPrior.availabilityTier(
            for: poi,
            reports: [report],
            asOf: Date()
        )
        #expect(tier == .ample)
    }
}
