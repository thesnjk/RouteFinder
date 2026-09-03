//
//  RouteFinderAppUITests.swift
//  RouteFinderAppUITests
//

import XCTest

final class RouteFinderAppUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 15
    private let menuTimeout: TimeInterval = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testColdLaunchShowsAuthOrMap() throws {
        let app = launchApp()
        let authField = app.textFields["authEmailField"]
        let mapMenu = app.buttons["mapToolbarMenu"]
        XCTAssertTrue(authField.waitForExistence(timeout: launchTimeout) || mapMenu.waitForExistence(timeout: launchTimeout))
    }

    @MainActor
    func testSettingsHubOpens() throws {
        let app = launchApp(skipAuth: true, openSettings: true)
        openSettingsHub(in: app)
    }

    @MainActor
    func testWalkaroundEntryExists() throws {
        let app = launchApp(skipAuth: true, hgvMode: true)
        let walkaround = app.buttons["walkaroundToolbarEntry"].firstMatch
        XCTAssertTrue(walkaround.waitForExistence(timeout: launchTimeout), "walkaroundToolbarEntry")
    }

    /// C8 proxy: Settings → API Keys (API Usage Today) + Legal → Driver Terms.
    @MainActor
    func testSettingsAPIUsageAndLegalDriverTerms() throws {
        let app = launchApp(skipAuth: true, openSettings: true)
        openSettingsHub(in: app)

        // Hub list: Vehicle → Navigation → Search → API Keys → Fleet → Offline → Legal
        app.swipeUp()
        let apiKeys = app.buttons["settingsAPIKeys"]
        XCTAssertTrue(apiKeys.waitForExistence(timeout: menuTimeout), "settingsAPIKeys")
        apiKeys.tap()
        XCTAssertTrue(app.staticTexts["API Usage Today"].waitForExistence(timeout: menuTimeout))

        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(
            identifiedElement("settingsVehicleHGV", in: app).firstMatch.waitForExistence(timeout: menuTimeout)
                || app.buttons["settingsVehicleHGV"].waitForExistence(timeout: 1)
        )

        app.swipeUp()
        let legal = app.buttons["settingsLegal"]
        XCTAssertTrue(legal.waitForExistence(timeout: menuTimeout), "settingsLegal")
        legal.tap()
        XCTAssertTrue(app.staticTexts["Driver Terms"].waitForExistence(timeout: menuTimeout))
    }

    /// Ph57: bottom peek search bar visible at launch.
    @MainActor
    func testMapSearchPeekBarAtLaunch() throws {
        let app = launchApp(skipAuth: true)
        let peekBar = app.buttons["mapSearchPeekBar"]
        XCTAssertTrue(peekBar.waitForExistence(timeout: launchTimeout), "mapSearchPeekBar")
    }

    /// Ph55: seeded route results sheet shows Start Navigation primary action.
    @MainActor
    func testStartNavigationButtonOnRouteResults() throws {
        let app = launchApp(skipAuth: true, seedRoute: true)
        let mapMenu = app.buttons["mapToolbarMenu"]
        XCTAssertTrue(mapMenu.waitForExistence(timeout: launchTimeout), "map should load")

        let startButton = app.buttons["startNavigationButton"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: launchTimeout),
            "startNavigationButton should appear after seeded route"
        )
        let label = startButton.label
        XCTAssertTrue(
            label.contains("Start Navigation") || label.contains("Start Simulation") || label.contains("Stop"),
            "Unexpected start button label: \(label)"
        )
        XCTAssertFalse(startButton.isHittable && app.buttons.matching(identifier: "startNavigationButton").count > 1)
    }

    /// Ph56: Route Overview toolbar button visible when route is loaded.
    @MainActor
    func testRouteOverviewButtonOnSeededRoute() throws {
        let app = launchApp(skipAuth: true, seedRoute: true)
        let overview = app.buttons["mapRouteOverviewButton"]
        XCTAssertTrue(overview.waitForExistence(timeout: launchTimeout), "mapRouteOverviewButton")
        XCTAssertTrue(overview.isEnabled)
    }

    /// C2: first-launch Car vs HGV vehicle mode sheet.
    @MainActor
    func testVehicleModeOnboardingCarAndHGV() throws {
        let app = launchApp(skipAuth: true, resetOnboarding: true)
        let carButton = app.buttons["vehicleModeCarButton"].firstMatch
        if !carButton.waitForExistence(timeout: launchTimeout) {
            dumpHierarchy(app, named: "vehicle-onboarding")
            // Fall back to combined label if identifier is coalesced.
            let byLabel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Car")).element
            XCTAssertTrue(byLabel.waitForExistence(timeout: 2), "vehicleModeCarButton")
            byLabel.tap()
        } else {
            carButton.tap()
        }
        XCTAssertFalse(
            app.buttons["vehicleModeCarButton"].waitForExistence(timeout: 3)
                || app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Car")).element.exists,
            "Car selection should dismiss vehicle sheet"
        )

        app.terminate()
        let appHGV = launchApp(skipAuth: true, resetOnboarding: true)
        let hgvButton = app.buttons["vehicleModeHGVButton"].firstMatch
        XCTAssertTrue(
            hgvButton.waitForExistence(timeout: launchTimeout)
                || app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "HGV")).element.waitForExistence(timeout: 2),
            "vehicleModeHGVButton"
        )
        if hgvButton.exists {
            hgvButton.tap()
        } else {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "HGV")).element.tap()
        }
        XCTAssertFalse(
            app.buttons["vehicleModeHGVButton"].waitForExistence(timeout: 3),
            "HGV selection should dismiss vehicle sheet"
        )
    }

    /// C2: orange cloud nag stays hidden when a mock ORS key is present.
    @MainActor
    func testCloudBannerHiddenWithMockKey() throws {
        let app = launchApp(skipAuth: true, mockORSKey: true)
        XCTAssertTrue(app.buttons["mapToolbarMenu"].waitForExistence(timeout: launchTimeout), "map should load")
        let banner = identifiedElement("cloudRoutingBanner", in: app)
        XCTAssertFalse(banner.waitForExistence(timeout: 3), "cloudRoutingBanner should be hidden with mock ORS key")
    }

    /// P0 step 6: seeded route shows Car profile badge.
    @MainActor
    func testRouteProfileBadgeOnSeededRoute() throws {
        let app = launchApp(skipAuth: true, seedRoute: true, mockORSKey: true, carMode: true)
        let badge = identifiedElement("routeProfileBadge", in: app).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: launchTimeout), "routeProfileBadge")
        XCTAssertTrue(
            badge.label.contains("Car"),
            "Expected Car in route profile badge, got: \(badge.label)"
        )
    }

    /// P0 step 7: Start Navigation / Simulation becomes Stop when active.
    @MainActor
    func testStartSimulationActivatesNavigation() throws {
        let app = launchApp(skipAuth: true, seedRoute: true)
        let startButton = app.buttons["startNavigationButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: launchTimeout), "startNavigationButton")

        if startButton.label.contains("Stop") {
            return
        }
        XCTAssertTrue(
            startButton.label.contains("Start"),
            "Expected Start label before activation, got: \(startButton.label)"
        )
        startButton.tap()

        let stopped = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] %@", "Stop"),
            object: startButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: launchTimeout), .completed, "button should become Stop")
    }

    /// Route loaded UX: active route chip visible after seed (at peek detent).
    @MainActor
    func testActiveRouteChipOnSeededRoute() throws {
        let app = launchApp(skipAuth: true, seedRoute: true, peekSheet: true)
        let chip = app.buttons["activeRouteChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: launchTimeout), "activeRouteChip")
    }

    @MainActor
    private func openSettingsHub(in app: XCUIApplication) {
        // Map chrome uses allowsHitTesting(false) so the map stays interactive; XCTest
        // cannot reliably tap the gear. UITEST_OPEN_SETTINGS presents Settings on launch.
        XCTAssertTrue(
            app.buttons["mapToolbarSettings"].waitForExistence(timeout: launchTimeout),
            "mapToolbarSettings should exist on the map chrome"
        )
        let vehicleRow = identifiedElement("settingsVehicleHGV", in: app).firstMatch
        if !vehicleRow.waitForExistence(timeout: menuTimeout) {
            dumpHierarchy(app, named: "settings-hub")
        }
        XCTAssertTrue(
            vehicleRow.waitForExistence(timeout: 1)
                || app.staticTexts["Vehicle & HGV"].waitForExistence(timeout: 1)
                || app.buttons["Vehicle & HGV"].waitForExistence(timeout: 1),
            "settingsVehicleHGV"
        )
    }

    private func dumpHierarchy(_ app: XCUIApplication, named name: String) {
        let path = "/tmp/rf-ui-\(name).txt"
        try? app.debugDescription.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func identifiedElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func launchApp(
        skipAuth: Bool = false,
        seedRoute: Bool = false,
        mockORSKey: Bool = false,
        carMode: Bool = false,
        hgvMode: Bool = false,
        resetOnboarding: Bool = false,
        peekSheet: Bool = false,
        openSettings: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if skipAuth {
            app.launchArguments += ["UITEST_SKIP_AUTH"]
            if !resetOnboarding {
                app.launchArguments += ["UITEST_SKIP_ONBOARDING"]
            }
        }
        if resetOnboarding {
            app.launchArguments += ["UITEST_RESET_ONBOARDING"]
        }
        if seedRoute {
            app.launchArguments += ["UITEST_SEED_ROUTE"]
        }
        if mockORSKey {
            app.launchArguments += ["UITEST_MOCK_ORS_KEY"]
        }
        if carMode {
            app.launchArguments += ["UITEST_CAR_MODE"]
        }
        if hgvMode {
            app.launchArguments += ["UITEST_HGV_MODE"]
        }
        if peekSheet {
            app.launchArguments += ["UITEST_PEEK_SHEET"]
        }
        if openSettings {
            app.launchArguments += ["UITEST_OPEN_SETTINGS"]
        }
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        return app
    }
}
