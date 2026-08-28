import Contracts
import CostModel
import Foundation
import Testing

struct CurveSpeedAdvisorTests {
    @Test func maxCurveSpeedMps_tightRadius_capsSpeed() {
        let speed = CurveSpeedAdvisor.maxCurveSpeedMps(radiusMeters: 20, lateralG: 0.16)
        #expect(speed > 5.0)
        #expect(speed < 6.5)
    }

    @Test func maxCurveSpeedMps_straightSection_returnsHighSpeed() {
        let speed = CurveSpeedAdvisor.maxCurveSpeedMps(radiusMeters: .infinity, lateralG: 0.32)
        #expect(speed.isInfinite)
    }

    @Test func maxUpcomingCurveSpeedMps_detectsSharpBendAhead() {
        let coordinates = [
            Coordinate(latitude: 51.5000, longitude: -0.1200),
            Coordinate(latitude: 51.5000, longitude: -0.1190),
            Coordinate(latitude: 51.5000, longitude: -0.1180),
            Coordinate(latitude: 51.4990, longitude: -0.1180),
            Coordinate(latitude: 51.4980, longitude: -0.1180),
        ]
        let segments = zip(coordinates, coordinates.dropFirst()).map { a, b in
            haversine(a, b)
        }
        var cumulative: [Double] = [0]
        for length in segments {
            cumulative.append(cumulative.last! + length)
        }

        let speed = CurveSpeedAdvisor.maxUpcomingCurveSpeedMps(
            cumulativeLengths: cumulative,
            coordinates: coordinates,
            arcLength: 0,
            lookaheadM: 500,
            lateralG: 0.16,
            currentSpeedMps: 10
        )

        #expect(speed < 15)
    }

    @Test func maxUpcomingCurveSpeedMps_straightRoadIgnoresAckermannSteer() {
        let coordinates = (0..<6).map { index in
            Coordinate(latitude: 52.628, longitude: 1.296 + Double(index) * 0.001)
        }
        let segments = zip(coordinates, coordinates.dropFirst()).map { haversine($0, $1) }
        var cumulative: [Double] = [0]
        for length in segments {
            cumulative.append(cumulative.last! + length)
        }

        let steerSnapshot = CentripetalSpeedGovernor.SteeringSnapshot(
            steerAngleRadians: 0.05,
            wheelbaseMeters: 2.7
        )
        let speed = CentripetalSpeedGovernor.maxUpcomingCurveSpeedMps(
            cumulativeLengths: cumulative,
            coordinates: coordinates,
            arcLength: cumulative[2],
            lookaheadM: 500,
            lateralG: 0.16,
            currentSpeedMps: 25,
            steeringSnapshot: steerSnapshot
        )

        #expect(speed.isInfinite)
    }

    @Test func maxUpcomingCurveSpeedMps_nearStraightDensifiedSpineAllowsResidentialCruise() {
        // ~5 m steps with tiny bearing noise (< 6°) — must not crush HGV cruise below ~12 m/s.
        var coordinates: [Coordinate] = []
        let startLat = 52.6300
        let startLon = 1.2970
        for index in 0..<40 {
            let wobble = (index % 2 == 0) ? 0.000002 : -0.000002
            coordinates.append(
                Coordinate(
                    latitude: startLat + Double(index) * 0.000045 + wobble,
                    longitude: startLon + Double(index) * 0.000010
                )
            )
        }
        let segments = zip(coordinates, coordinates.dropFirst()).map { haversine($0, $1) }
        var cumulative: [Double] = [0]
        for length in segments {
            cumulative.append(cumulative.last! + length)
        }

        let speed = CentripetalSpeedGovernor.maxUpcomingCurveSpeedMps(
            cumulativeLengths: cumulative,
            coordinates: coordinates,
            arcLength: 0,
            lookaheadM: 80,
            lateralG: 0.16,
            currentSpeedMps: 10
        )

        // Residential 30 mph ≈ 13.4 m/s; governor should not bind densify noise.
        #expect(speed.isInfinite || speed >= 12.0)
    }

    private func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
