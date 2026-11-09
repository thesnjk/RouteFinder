import Contracts
import Foundation
import Testing

struct VehicleProfileComboLengthTests {
    @Test func ukArticPresetHasOneTrailer() {
        #expect(VehicleProfile.ukArtic.trailerCount == 1)
        #expect(VehicleProfile.ukArtic.usesArticulatedTrailer)
        #expect(VehicleProfile.ukArtic.resolvedTrailerCount == 1)
    }

    @Test func ukRigidPresetHasZeroTrailers() {
        #expect(VehicleProfile.ukRigid26t.trailerCount == 0)
        #expect(!VehicleProfile.ukRigid26t.usesArticulatedTrailer)
    }

    @Test func explicitZeroTrailersForcesRigidDespiteLongLength() {
        let profile = VehicleProfile(length: 16.5, trailerCount: 0)
        #expect(!profile.usesArticulatedTrailer)
    }

    @Test func legacyNilTrailerCountFallsBackToLength() {
        let long = VehicleProfile(length: 16.5, trailerCount: nil)
        let short = VehicleProfile(length: 5.0, trailerCount: nil)
        #expect(long.usesArticulatedTrailer)
        #expect(!short.usesArticulatedTrailer)
    }

    @Test func trailerCountClampsToThree() {
        let profile = VehicleProfile(trailerCount: 99)
        #expect(profile.trailerCount == 3)
        #expect(profile.resolvedTrailerCount == 3)
    }

    @Test func suggestedOverallLengthLadder() {
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: 0) == 12.0)
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: 1) == 16.5)
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: 2) == 18.75)
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: 3) == 25.25)
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: -1) == 12.0)
        #expect(VehicleProfile.suggestedOverallLengthMeters(trailerCount: 99) == 25.25)
    }

    @Test func codableRoundTripPreservesTrailerCount() throws {
        let profile = VehicleProfile.ukArtic
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(VehicleProfile.self, from: data)
        #expect(decoded.trailerCount == 1)
        #expect(decoded.length == 16.5)
    }

    @Test func codableMissingTrailerCountDecodesAsNil() throws {
        let json = #"""
        {"height":4,"weight":44,"width":2.55,"length":16.5}
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VehicleProfile.self, from: json)
        #expect(decoded.trailerCount == nil)
        #expect(decoded.usesArticulatedTrailer)
    }
}
