import Contracts
import Foundation
import Testing

struct VehicleWorkspaceSettingsTests {
    @Test func roundTripsSnapshotThroughUserDefaults() {
        let suiteName = "RouteFinder.WorkspaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        let snapshot = VehicleWorkspaceSnapshot(
            vehicleRegistration: "YF72 ADV",
            isHGVMode: true,
            vehicleHeight: "4.2",
            vehicleWeight: "44",
            vehicleWidth: "2.55",
            vehicleLength: "16.5",
            vehicleAxleWeight: "11.5",
            vehicleGroundClearance: "0.35",
            vehicleTurningRadius: "12.5",
            vehicleEnginePowerHP: "450",
            activeProfileName: "UK Artic",
            hazmatClassRaw: HazmatClass.none.rawValue,
            emissionClassRaw: EmissionClass.euro6.rawValue,
            avoidNonCompliantLEZ: true,
            avoidResidential: false
        )

        VehicleWorkspaceSettings.save(snapshot, defaults: defaults)
        let loaded = VehicleWorkspaceSettings.load(defaults: defaults)

        #expect(loaded == snapshot)
    }
}

struct SessionWorkspaceSettingsTests {
    @Test func persistsLastEmailAndRequireLoginFlag() {
        let suiteName = "RouteFinder.SessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            SessionWorkspaceSettings.clearRememberedSession(defaults: defaults)
            UserDefaults.standard.removeSuite(named: suiteName)
        }

        SessionWorkspaceSettings.saveLastUserID("user-123", defaults: defaults)
        SessionWorkspaceSettings.saveLastEmail("driver@example.com", defaults: defaults)
        SessionWorkspaceSettings.saveRequireLoginEachLaunch(true, defaults: defaults)

        #expect(SessionWorkspaceSettings.loadLastUserID(defaults: defaults) == "user-123")
        #expect(SessionWorkspaceSettings.loadLastEmail(defaults: defaults) == "driver@example.com")
        #expect(SessionWorkspaceSettings.loadRequireLoginEachLaunch(defaults: defaults) == true)

        SessionWorkspaceSettings.clearRememberedSession(defaults: defaults)
        #expect(SessionWorkspaceSettings.loadLastUserID(defaults: defaults) == nil)
        #expect(SessionWorkspaceSettings.loadLastEmail(defaults: defaults) == nil)
    }
}
