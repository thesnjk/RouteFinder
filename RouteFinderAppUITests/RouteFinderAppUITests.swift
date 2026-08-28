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
