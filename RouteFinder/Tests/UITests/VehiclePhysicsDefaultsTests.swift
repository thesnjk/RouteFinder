import Contracts
import RouteController
import Testing
@testable import UI

@MainActor
struct VehiclePhysicsDefaultsTests {
    @Test func resolvedVehicleProfile_appliesPassengerDefaults() {
        let viewModel = RouteViewModel()
        viewModel.isHGVMode = false

        let profile = viewModel.resolvedVehicleProfile()
        #expect(profile.turningRadius == 5.0)
        #expect(profile.axleWeight == 0.75)
        #expect(profile.groundClearance == 0.15)
    }

    @Test func resolvedVehicleProfile_preservesUserOverride() {
        let viewModel = RouteViewModel()
        viewModel.isHGVMode = false
        viewModel.vehicleTurningRadius = "8.5"
        viewModel.markPhysicsFieldEdited(.turningRadius, text: "8.5")

        let profile = viewModel.resolvedVehicleProfile()
        #expect(profile.turningRadius == 8.5)
    }

    @Test func physicsPlaceholder_showsClassDefaultWhenEmpty() {
        let viewModel = RouteViewModel()
        viewModel.isHGVMode = true

        #expect(viewModel.physicsPlaceholder(for: .turningRadius) == "12.5")
    }
}
