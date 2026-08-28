import Contracts
import Foundation
import RouteController
import Testing

struct LiveTrafficHazardSamplerTests {
    @Test func shouldPollRespectsInterval() {
        let now = Date()
        let recent = now.addingTimeInterval(-10)
        #expect(!LiveTrafficHazardSampler.shouldPoll(lastSampleDate: recent, now: now))
        #expect(LiveTrafficHazardSampler.shouldPoll(lastSampleDate: nil, now: now))
    }

    @Test func samplePointsAheadReturnsIncreasingArcLengths() {
        let route = [
            Coordinate(latitude: 51.50, longitude: -0.10),
            Coordinate(latitude: 51.55, longitude: -0.05),
            Coordinate(latitude: 51.60, longitude: 0.00),
        ]
        let points = LiveTrafficHazardSampler.samplePointsAhead(
            route: route,
            currentArcLengthMeters: 1000,
            offsetsMeters: [2000, 5000]
        )
        #expect(points.count == 2)
        #expect(points[0].arcLengthMeters == 3000)
        #expect(points[1].arcLengthMeters == 6000)
    }

    @Test func hazardHitRequiresRerouteWorthyFlow() {
        let flow = TomTomFlowSegmentData(
            currentSpeedKmh: 0,
            freeFlowSpeedKmh: 90,
            confidence: 0.9,
            roadClosed: false
        )
        let snapshot = VehicleAdjustedTrafficClassifier.snapshot(
            from: flow,
            vehicleClass: .heavyGoodsVehicle
        )
        let sample = Coordinate(latitude: 51.5, longitude: -0.1)
        let hit = LiveTrafficHazardSampler.hazardHit(
            flow: flow,
            snapshot: snapshot,
            sample: sample,
            arcLengthMeters: 5000
        )
        #expect(hit != nil)
        #expect(hit?.isRoadClosed == false)
    }
}
