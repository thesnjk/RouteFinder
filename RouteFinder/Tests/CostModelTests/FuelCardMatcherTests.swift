import Contracts
import Foundation
import Testing

struct FuelCardMatcherTests {
    @Test func matchesKeyfuelsByLabelSubstring() {
        let poi = TruckPoi(
            id: "fuel-1",
            kind: .highFlowDiesel,
            latitude: 51.5,
            longitude: -0.1,
            label: "Keyfuels Truck Stop",
            amenities: ["fuel", "brand:keyfuels"]
        )
        #expect(FuelCardMatcher.accepts(provider: .keyfuels, poi: poi))
        #expect(!FuelCardMatcher.accepts(provider: .bp, poi: poi))
    }

    @Test func matchesBrandAmenityWhenLabelIsGeneric() {
        let poi = TruckPoi(
            id: "fuel-2",
            kind: .highFlowDiesel,
            latitude: 51.5,
            longitude: -0.1,
            label: "HGV fuel",
            amenities: ["fuel", "brand:esso"]
        )
        #expect(FuelCardMatcher.accepts(provider: .esso, poi: poi))
    }

    @Test func ignoresNonFuelPois() {
        let poi = TruckPoi(
            id: "park-1",
            kind: .overnightSecureParking,
            latitude: 51.5,
            longitude: -0.1,
            label: "BP Truck Park",
            amenities: ["brand:bp"]
        )
        #expect(!FuelCardMatcher.accepts(provider: .bp, poi: poi))
    }

    @Test func bannerMessageReflectsMatchCount() {
        #expect(FuelCardMatcher.aheadBannerMessage(provider: .none, matchingCount: 2) == nil)
        #expect(FuelCardMatcher.aheadBannerMessage(provider: .bp, matchingCount: 0) == nil)
        #expect(FuelCardMatcher.aheadBannerMessage(provider: .bp, matchingCount: 1) == "Accepts your BP card ahead")
        #expect(FuelCardMatcher.aheadBannerMessage(provider: .ukFuels, matchingCount: 3) == "3 stops ahead accept your UK Fuels card")
    }
}
