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
        let app = launchApp(skipAuth: true)
        let mapMenu = app.buttons["mapToolbarMenu"]
        XCTAssertTrue(mapMenu.waitForExistence(timeout: launchTimeout))
        mapMenu.tap()

        let settingsEntry = app.buttons["mapToolbarSettings"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: menuTimeout))
        settingsEntry.tap()

        XCTAssertTrue(app.buttons["settingsVehicleHGV"].waitForExistence(timeout: menuTimeout))
    }

    @MainActor
    func testWalkaroundEntryExists() throws {
        let app = launchApp(skipAuth: true)
        let mapMenu = app.buttons["mapToolbarMenu"]
        XCTAssertTrue(mapMenu.waitForExistence(timeout: launchTimeout))
        mapMenu.tap()

        XCTAssertTrue(app.buttons["walkaroundToolbarEntry"].waitForExistence(timeout: menuTimeout))
    }

    /// C8 proxy: Settings → API Keys (API Usage Today) + Legal → Driver Terms.
    @MainActor
    func testSettingsAPIUsageAndLegalDriverTerms() throws {
        let app = launchApp(skipAuth: true)
        openSettingsHub(in: app)

        // Hub list: Vehicle → Navigation → Search → API Keys → Fleet → Offline → Legal
        app.swipeUp()
        let apiKeys = app.buttons["settingsAPIKeys"]
        XCTAssertTrue(apiKeys.waitForExistence(timeout: menuTimeout), "settingsAPIKeys")
        apiKeys.tap()
        XCTAssertTrue(app.staticTexts["API Usage Today"].waitForExistence(timeout: menuTimeout))

        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settingsVehicleHGV"].waitForExistence(timeout: menuTimeout))

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

    @MainActor
    private func openSettingsHub(in app: XCUIApplication) {
        let mapMenu = app.buttons["mapToolbarMenu"]
        XCTAssertTrue(mapMenu.waitForExistence(timeout: launchTimeout))
        mapMenu.tap()

        let settingsEntry = app.buttons["mapToolbarSettings"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: menuTimeout))
        settingsEntry.tap()

        XCTAssertTrue(app.buttons["settingsVehicleHGV"].waitForExistence(timeout: menuTimeout))
    }

    @MainActor
    private func launchApp(skipAuth: Bool = false, seedRoute: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if skipAuth {
            app.launchArguments += ["UITEST_SKIP_AUTH", "UITEST_SKIP_ONBOARDING"]
        }
        if seedRoute {
            app.launchArguments += ["UITEST_SEED_ROUTE"]
        }
        app.launch()
        return app
    }
}
