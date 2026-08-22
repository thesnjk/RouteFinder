import Contracts
import Foundation
import Testing
@testable import CostModel

struct ElevationGapFillerTests {
    @Test func fillGaps_interpolatesMissingMiddleSamples() {
        let coordinates = [
            Coordinate(latitude: 51.5, longitude: -0.12, elevationMeters: 100),
            Coordinate(latitude: 51.51, longitude: -0.12, elevationMeters: nil),
            Coordinate(latitude: 51.52, longitude: -0.12, elevationMeters: 200),
        ]

        let filled = ElevationGapFiller.fillGaps(in: coordinates)

        #expect(filled[1].elevationMeters == 150)
    }
}

struct ElevationProfileInterpolationTests {
    @Test func gradePercentInterpolatesWithinSegment() {
        let coordinates = [
            Coordinate(latitude: 51.5, longitude: -0.12, elevationMeters: 0),
            Coordinate(latitude: 51.51, longitude: -0.12, elevationMeters: 20),
            Coordinate(latitude: 51.52, longitude: -0.12, elevationMeters: 80),
            Coordinate(latitude: 51.53, longitude: -0.12, elevationMeters: 100),
        ]
        let profile = ElevationProfile(coordinates: coordinates)
        let segmentStart = profile.cumulativeLengths[1]
        let segmentEnd = profile.cumulativeLengths[2]
        let midArc = (segmentStart + segmentEnd) / 2

        let midGrade = profile.gradePercent(atArcLength: midArc)
        let startGrade = profile.gradesPercent[1]
        let endGrade = profile.gradesPercent[2]

        #expect(startGrade != endGrade)
        #expect(midGrade > min(startGrade, endGrade))
        #expect(midGrade < max(startGrade, endGrade))
    }

    @Test func elevationMetersInterpolatesAlongRoute() {
        let coordinates = [
            Coordinate(latitude: 51.5, longitude: -0.12, elevationMeters: 0),
            Coordinate(latitude: 51.51, longitude: -0.12, elevationMeters: 100),
        ]
        let profile = ElevationProfile(coordinates: coordinates)
        let midArc = profile.cumulativeLengths[1] / 2

        let elevation = profile.elevationMeters(atArcLength: midArc)

        #expect(elevation == 50)
    }
}
