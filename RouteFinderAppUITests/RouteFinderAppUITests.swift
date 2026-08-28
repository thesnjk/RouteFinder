//
//  RouteFinderAppUITests.swift
//  RouteFinderAppUITests
//

import XCTest

final class RouteFinderAppUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 15

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
        XCTAssertTrue(app.buttons["mapToolbarMenu"].waitForExistence(timeout: launchTimeout))

        app.buttons["mapToolbarMenu"].tap()
        XCTAssertTrue(app.buttons["mapToolbarSettings"].waitForExistence(timeout: 5))
        app.buttons["mapToolbarSettings"].tap()

        XCTAssertTrue(app.buttons["settingsVehicleHGV"].waitForExistence(timeout: launchTimeout))
    }

    @MainActor
    func testWalkaroundEntryExists() throws {
        let app = launchApp(skipAuth: true)
        XCTAssertTrue(app.buttons["mapToolbarMenu"].waitForExistence(timeout: launchTimeout))

        app.buttons["mapToolbarMenu"].tap()
        XCTAssertTrue(app.buttons["walkaroundToolbarEntry"].waitForExistence(timeout: 5))
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
