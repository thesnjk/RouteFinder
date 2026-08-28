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

struct NavigationWorkspaceSettingsTests {
    @Test func productOnboardingSeenRoundTripsThroughUserDefaults() {
        let suiteName = "RouteFinder.NavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(!NavigationWorkspaceSettings.loadHasSeenProductOnboarding(defaults: defaults))

        NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true, defaults: defaults)
        #expect(NavigationWorkspaceSettings.loadHasSeenProductOnboarding(defaults: defaults))
    }

    @Test func routingLiabilityAcceptedRoundTripsThroughUserDefaults() {
        let suiteName = "RouteFinder.NavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(!NavigationWorkspaceSettings.loadHasAcceptedRoutingLiability(defaults: defaults))

        NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true, defaults: defaults)
        #expect(NavigationWorkspaceSettings.loadHasAcceptedRoutingLiability(defaults: defaults))
    }

    @Test func laybyVoiceAlertsDefaultOnAndRoundTrip() {
        let suiteName = "RouteFinder.NavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(NavigationWorkspaceSettings.loadLaybyVoiceAlertsEnabled(defaults: defaults))
        NavigationWorkspaceSettings.saveLaybyVoiceAlertsEnabled(false, defaults: defaults)
        #expect(!NavigationWorkspaceSettings.loadLaybyVoiceAlertsEnabled(defaults: defaults))
    }

    @Test func laybyAlertDistanceDefaultsToFiveKm() {
        let suiteName = "RouteFinder.NavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(NavigationWorkspaceSettings.loadLaybyAlertDistanceMeters(defaults: defaults) == 5000)
        NavigationWorkspaceSettings.saveLaybyAlertDistanceMeters(7500, defaults: defaults)
        #expect(NavigationWorkspaceSettings.loadLaybyAlertDistanceMeters(defaults: defaults) == 7500)
    }

    @Test func fuelCardProviderDefaultsToNoneAndRoundTrips() {
        let suiteName = "RouteFinder.NavigationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(NavigationWorkspaceSettings.loadFuelCardProvider(defaults: defaults) == .none)
        NavigationWorkspaceSettings.saveFuelCardProvider(.keyfuels, defaults: defaults)
        #expect(NavigationWorkspaceSettings.loadFuelCardProvider(defaults: defaults) == .keyfuels)
    }
}

struct LanguageWorkspaceSettingsTests {
    @Test func preferredMapLabelLanguageRoundTripsThroughUserDefaults() {
        let suiteName = "RouteFinder.LanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        #expect(LanguageWorkspaceSettings.loadPreferredMapLabelLanguage(defaults: defaults) == "en")

        LanguageWorkspaceSettings.savePreferredMapLabelLanguage("de", defaults: defaults)
        #expect(LanguageWorkspaceSettings.loadPreferredMapLabelLanguage(defaults: defaults) == "de")
    }

    @Test func mapLabelNamePropertyCandidatesIncludeNorwegianFallbacks() {
        let nbCandidates = LanguageWorkspaceSettings.mapLabelNamePropertyCandidates(for: "nb")
        #expect(nbCandidates.contains("name:nb"))
        #expect(nbCandidates.contains("name:no"))

        let nnCandidates = LanguageWorkspaceSettings.mapLabelNamePropertyCandidates(for: "nn")
        #expect(nnCandidates.contains("name:nn"))
        #expect(nnCandidates.contains("name:no"))

        let deCandidates = LanguageWorkspaceSettings.mapLabelNamePropertyCandidates(for: "de")
        #expect(deCandidates.first == "name:de")
    }
}
