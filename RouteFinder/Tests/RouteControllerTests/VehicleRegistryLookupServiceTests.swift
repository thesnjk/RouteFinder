import Foundation
import Testing
@testable import RouteController

struct VehicleRegistryLookupServiceTests {
  @Test func carRegistrationMapsToPassengerProfile() {
    let profile = VehicleRegistryLookupService.lookup(registration: "CAR-REG")
    #expect(profile != nil)
    #expect(profile?.vehicleType == .passengerCar)
    #expect(profile?.heightM == 1.5)
    #expect(profile?.widthM == 1.8)
    #expect(profile?.lengthM == 4.5)
    #expect(profile?.weightTonnes == 1.8)
    #expect(profile?.axleCount == 2)
    #expect(profile?.enginePowerHP == 150)
    #expect(profile?.isHGVMode == false)
  }

  @Test func truckRegistrationMapsToHGVProfile() {
    let profile = VehicleRegistryLookupService.lookup(registration: "TRUCK-44T")
    #expect(profile != nil)
    #expect(profile?.vehicleType == .hgv)
    #expect(profile?.heightM == 4.0)
    #expect(profile?.widthM == 2.55)
    #expect(profile?.lengthM == 16.5)
    #expect(profile?.weightTonnes == 44.0)
    #expect(profile?.axleCount == 6)
    #expect(profile?.enginePowerHP == 500)
    #expect(profile?.isHGVMode == true)
  }

  @Test func unknownRegistrationReturnsNil() {
    #expect(VehicleRegistryLookupService.lookup(registration: "UNKNOWN123") == nil)
    #expect(VehicleRegistryLookupService.lookup(registration: "   ") == nil)
  }

  @Test func regionalFallbackParsesUKPlate() {
    let profile = RegionalPlateFallbackParser.parse(registration: "AB12 CDE", region: .uk)
    #expect(profile != nil)
    #expect(profile?.vehicleType == .passengerCar)
  }
}
