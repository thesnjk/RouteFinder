import Foundation
import Testing
@testable import UI

@Suite("FleetSetupWizardAdvancePolicy")
struct FleetSetupWizardAdvancePolicyTests {
    @Test func testStepRequiresConnectedStatus() {
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: nil,
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: "Fleet API key rejected. Check the shared key with the operator.",
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: "Auth failed · Fleet API key rejected. Check the shared key with the operator.",
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: "Offline",
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: nil,
                urlText: "",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: "Connected to fleet server.",
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .test,
                connectionStatus: "Connected · v1",
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
    }

    @Test func discoverStepValidatesURLScheme() {
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .discover,
                connectionStatus: nil,
                urlText: "http://192.168.1.10:8080",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .discover,
                connectionStatus: nil,
                urlText: "http://192.168.1.10:8080",
                isHosted: true,
                vehicleIdText: ""
            )
        )
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .discover,
                connectionStatus: nil,
                urlText: "https://fleet.example.com",
                isHosted: true,
                vehicleIdText: ""
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .discover,
                connectionStatus: nil,
                urlText: "  ",
                isHosted: false,
                vehicleIdText: ""
            )
        )
    }

    @Test func vehicleStepRequiresUUID() {
        let id = UUID().uuidString
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .vehicle,
                connectionStatus: "Connected to fleet server.",
                urlText: "http://127.0.0.1:8080",
                isHosted: false,
                vehicleIdText: id
            )
        )
        #expect(
            !FleetSetupWizardAdvancePolicy.canAdvance(
                step: .vehicle,
                connectionStatus: "Connected to fleet server.",
                urlText: "http://127.0.0.1:8080",
                isHosted: false,
                vehicleIdText: "not-a-uuid"
            )
        )
    }

    @Test func enableRemoteAndDoneAlwaysAdvance() {
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .enableRemote,
                connectionStatus: nil,
                urlText: "",
                isHosted: false,
                vehicleIdText: ""
            )
        )
        #expect(
            FleetSetupWizardAdvancePolicy.canAdvance(
                step: .done,
                connectionStatus: nil,
                urlText: "",
                isHosted: false,
                vehicleIdText: ""
            )
        )
    }
}
