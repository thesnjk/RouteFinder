import Foundation
import Testing
@testable import RouteController

struct RegionalPlateFallbackParserTests {
    @Test func legacyDemoPlatesStillResolve() {
        let car = RegionalPlateFallbackParser.parse(registration: "CAR-REG", region: .auto)
        #expect(car?.vehicleType == .passengerCar)

        let truck = RegionalPlateFallbackParser.parse(registration: "TRUCK-44T", region: .auto)
        #expect(truck?.isHGVMode == true)
    }

    @Test func ukPlateFormatInfersPassengerProfile() {
        let profile = RegionalPlateFallbackParser.parse(registration: "AB12 CDE", region: .uk)
        #expect(profile != nil)
        #expect(profile?.vehicleType == .passengerCar)
    }

    @Test func ukHGVHintInfersArticProfile() {
        let profile = RegionalPlateFallbackParser.parse(registration: "HGV-44T", region: .uk)
        #expect(profile?.isHGVMode == true)
        #expect(profile?.weightTonnes == 44.0)
    }

    @Test func detectsUKRegionFromPlate() {
        #expect(RegionalPlateFallbackParser.detectRegion(from: "AB12CDE") == .uk)
        #expect(RegionalPlateFallbackParser.isUKPlate("AB12 CDE"))
    }

    @Test func usPlateInfersLightVehicle() {
        let profile = RegionalPlateFallbackParser.parse(registration: "ABC1234", region: .us)
        #expect(profile?.vehicleType == .passengerCar)
    }
}
