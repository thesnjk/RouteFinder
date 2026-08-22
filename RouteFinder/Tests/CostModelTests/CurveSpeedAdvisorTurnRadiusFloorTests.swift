import Contracts
import CostModel
import Testing

struct CurveSpeedAdvisorTurnRadiusFloorTests {
    @Test func minimumTurnRadius_raisesCapWhenPolylineRadiusIsTighter() {
        let coordinates = [
            Coordinate(latitude: 51.50000, longitude: -0.130000),
            Coordinate(latitude: 51.50000, longitude: -0.129900),
            Coordinate(latitude: 51.499900, longitude: -0.129900),
        ]
        let cumulative = [0.0, 7.0, 14.0]

        let rawCap = CurveSpeedAdvisor.maxUpcomingCurveSpeedMps(
            cumulativeLengths: cumulative,
            coordinates: coordinates,
            arcLength: 0,
            lookaheadM: 20,
            lateralG: 0.32,
            currentSpeedMps: 5
        )

        let flooredCap = CurveSpeedAdvisor.maxUpcomingCurveSpeedMps(
            cumulativeLengths: cumulative,
            coordinates: coordinates,
            arcLength: 0,
            lookaheadM: 20,
            lateralG: 0.32,
            currentSpeedMps: 5,
            minimumTurnRadiusMeters: 100
        )

        #expect(rawCap.isFinite)
        #expect(flooredCap.isFinite)
        #expect(flooredCap > rawCap)
    }
}
