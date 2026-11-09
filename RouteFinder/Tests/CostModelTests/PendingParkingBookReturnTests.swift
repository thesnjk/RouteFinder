import Contracts
import Foundation
import Testing

struct PendingParkingBookReturnTests {
    @Test func ctaCaptionByTier() {
        #expect(ParkingBookCTACopy.caption(for: nil) == nil)
        #expect(ParkingBookCTACopy.caption(for: .ample) == nil)
        #expect(ParkingBookCTACopy.caption(for: .limited)?.contains("fill soon") == true)
        #expect(ParkingBookCTACopy.caption(for: .full)?.contains("full") == true)
    }

    @Test func travisEmphasisOnlyForAmple() {
        #expect(ParkingBookCTACopy.emphasizesTravis(for: .ample))
        #expect(!ParkingBookCTACopy.emphasizesTravis(for: .limited))
        #expect(!ParkingBookCTACopy.emphasizesTravis(for: .full))
        #expect(ParkingBookCTACopy.usesSecondaryBookStyle(for: .full))
        #expect(!ParkingBookCTACopy.usesSecondaryBookStyle(for: .ample))
    }

    @Test func pendingFreshnessWindow() {
        let now = Date()
        let fresh = PendingParkingBookReturn(
            id: "a",
            label: "Keele",
            latitude: 53.0,
            longitude: -2.2,
            partner: .travis,
            openedAt: now.addingTimeInterval(-60),
            tier: .ample
        )
        #expect(fresh.isFresh(asOf: now))
        #expect(fresh.resumeMessage.contains("TRAVIS"))
        #expect(fresh.resumeMessage.contains("Keele"))

        let stale = PendingParkingBookReturn(
            id: "b",
            label: "Old",
            latitude: 53.0,
            longitude: -2.2,
            partner: .snap,
            openedAt: now.addingTimeInterval(-(PendingParkingBookReturn.freshnessLimitSeconds + 1)),
            tier: .full
        )
        #expect(!stale.isFresh(asOf: now))
    }
}
