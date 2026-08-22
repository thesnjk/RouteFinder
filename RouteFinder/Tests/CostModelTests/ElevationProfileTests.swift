import Contracts
import CostModel
import Foundation
import Testing

struct ElevationProfileTests {
    @Test func computesGradePercentAlongSlope() {
        let coordinates = [
            Coordinate(latitude: 51.5000, longitude: -0.1200, elevationMeters: 100),
            Coordinate(latitude: 51.5000, longitude: -0.1190, elevationMeters: 106),
        ]

        let profile = ElevationProfile(coordinates: coordinates)
        #expect(profile.gradesPercent.count == 1)
        #expect(profile.gradesPercent[0] > 5.0)
    }

    @Test func gradeAtArcLengthSamplesSegment() {
        let coordinates = [
            Coordinate(latitude: 51.5000, longitude: -0.1200, elevationMeters: 0),
            Coordinate(latitude: 51.5000, longitude: -0.1190, elevationMeters: 10),
            Coordinate(latitude: 51.5000, longitude: -0.1180, elevationMeters: 10),
        ]

        let profile = ElevationProfile(coordinates: coordinates)
        let grade = profile.gradePercent(atArcLength: profile.cumulativeLengths[1] * 0.5)
        #expect(grade > 0)
    }

    @Test func flatRouteHasNearZeroGrade() {
        let coordinates = [
            Coordinate(latitude: 51.5000, longitude: -0.1200, elevationMeters: 50),
            Coordinate(latitude: 51.5000, longitude: -0.1190, elevationMeters: 50),
            Coordinate(latitude: 51.5000, longitude: -0.1180, elevationMeters: 50),
        ]

        let profile = ElevationProfile(coordinates: coordinates)
        #expect(abs(profile.maxAbsoluteGradePercent) < 0.01)
    }
}
