import CoreLocation
import SharedCore
import Testing

struct SignificantLocationGateTests {
    @Test func firstFixAlwaysFetches() {
        let london = CLLocation(latitude: 51.5074, longitude: -0.1278)
        #expect(SignificantLocationGate.shouldFetch(from: nil, to: london))
    }

    @Test func shortMoveDoesNotFetch() {
        let start = CLLocation(latitude: 51.5074, longitude: -0.1278)
        let nearby = CLLocation(latitude: 51.5100, longitude: -0.1300)
        #expect(!SignificantLocationGate.shouldFetch(from: start, to: nearby))
    }

    @Test func longMoveFetches() {
        let start = CLLocation(latitude: 51.5074, longitude: -0.1278)
        let norwich = CLLocation(latitude: 52.6309, longitude: 1.2974)
        #expect(SignificantLocationGate.shouldFetch(from: start, to: norwich))
    }
}
