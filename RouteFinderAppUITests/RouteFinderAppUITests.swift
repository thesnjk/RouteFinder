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
    private func launchApp(skipAuth: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if skipAuth {
            app.launchArguments += ["UITEST_SKIP_AUTH", "UITEST_SKIP_ONBOARDING"]
        }
        app.launch()
        return app
    }
}
