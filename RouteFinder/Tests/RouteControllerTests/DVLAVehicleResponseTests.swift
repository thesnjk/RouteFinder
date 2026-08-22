import Contracts
import Foundation
import Testing
@testable import RouteController

struct DVLAVehicleResponseTests {
    @Test func mapsRevenueWeightToTonnes() {
        let response = DVLAVehicleResponse(
            make: "VOLVO",
            model: "FH",
            revenueWeight: 44000,
            wheelplan: "ARTIC"
        )

        let profile = response.toRegistryProfile()
        #expect(profile.weightTonnes == 44.0)
        #expect(profile.isHGVMode)
        #expect(profile.axleCount == 6)
        #expect(profile.displayName == "VOLVO FH")
    }

    @Test func passengerCarUsesLightDefaults() {
        let response = DVLAVehicleResponse(
            make: "FORD",
            model: "FOCUS",
            fuelType: "PETROL",
            revenueWeight: 1800
        )

        let profile = response.toRegistryProfile()
        #expect(profile.vehicleType == VehicleRegistryType.passengerCar)
        #expect(profile.weightTonnes == 1.8)
        #expect(!profile.isHGVMode)
    }

    @Test func euroStatusMapsToEmissionClass() {
        let response = DVLAVehicleResponse(
            make: "SCANIA",
            model: "R450",
            euroStatus: "EURO 6",
            revenueWeight: 36000,
            wheelplan: "ARTIC"
        )

        let profile = response.toRegistryProfile()
        #expect(profile.emissionClass == EmissionClass.euro6)
    }
}
