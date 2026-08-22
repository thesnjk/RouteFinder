import CoreLocation
import Foundation
import RouteController
import Testing

struct VehicleGeometryCalculatorTests {
    private let rearAxle = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)

    private func distanceMeters(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadiusMeters = 6_378_137.0
        let lat1 = from.latitude * Double.pi / 180.0
        let lat2 = to.latitude * Double.pi / 180.0
        let deltaLat = (to.latitude - from.latitude) * Double.pi / 180.0
        let deltaLon = (to.longitude - from.longitude) * Double.pi / 180.0
        let sinDLat = sin(deltaLat / 2.0)
        let sinDLon = sin(deltaLon / 2.0)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2.0 * earthRadiusMeters * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h)))
    }

    @Test func polygonClosesRing() {
        let ring = VehicleGeometryCalculator.generateFootprint(
            rearAxle: rearAxle,
            headingDegrees: 0,
            lengthMeters: 12,
            widthMeters: 2.55
        )
        #expect(ring.count == 5)
        #expect(ring.first?.latitude == ring.last?.latitude)
        #expect(ring.first?.longitude == ring.last?.longitude)
    }

    @Test func northBearingAlignsLongAxisNorthSouth() {
        let ring = VehicleGeometryCalculator.generateFootprint(
            rearAxle: rearAxle,
            headingDegrees: 0,
            lengthMeters: 100,
            widthMeters: 20
        )
        let frontRight = ring[0]
        let frontLeft = ring[1]
        let rearLeft = ring[2]
        let rearRight = ring[3]

        #expect(frontLeft.latitude > rearAxle.latitude)
        #expect(abs(rearLeft.latitude - rearAxle.latitude) < 0.0001)
        #expect(abs(frontLeft.longitude - rearAxle.longitude) < 0.0003)
        #expect(abs(rearRight.longitude - rearAxle.longitude) < 0.0003)
        #expect(abs(frontLeft.latitude - frontRight.latitude) < 0.0001)
    }

    @Test func cornerDistancesMatchRearAxleDimensions() {
        let length = 12.0
        let width = 2.55
        let ring = VehicleGeometryCalculator.generateFootprint(
            rearAxle: rearAxle,
            headingDegrees: 45,
            lengthMeters: length,
            widthMeters: width
        )

        let frontLeft = ring[1]
        let distance = distanceMeters(from: rearAxle, to: frontLeft)
        let expected = hypot(length, width / 2.0)
        #expect(abs(distance - expected) < 1.0)
    }
}
