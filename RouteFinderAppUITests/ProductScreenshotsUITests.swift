import XCTest

/// Captures README product screenshots under `Docs/screenshots/`.
/// Run with: `xcodebuild test -only-testing:RouteFinderAppUITests/ProductScreenshotsUITests ...`
final class ProductScreenshotsUITests: XCTestCase {
    private var screenshotDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs/screenshots", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
    }

    @MainActor
    func testCaptureProductScreenshots() throws {
        addUIInterruptionMonitor(withDescription: "Location") { alert in
            if alert.buttons["Allow While Using App"].exists {
                alert.buttons["Allow While Using App"].tap()
                return true
            }
            if alert.buttons["Allow Once"].exists {
                alert.buttons["Allow Once"].tap()
                return true
            }
            return false
        }

        // 1) Route map after seeded HGV route
        let mapApp = launchSeededApp(extra: [])
        mapApp.tap()
        dismissAlerts(in: mapApp)
        XCTAssertTrue(waitForStartControl(in: mapApp), "Expected Start Navigation/Simulation")
        try saveScreenshot(named: "ios-route-map.png", of: mapApp)

        // 2) Active simulation / rehearse chrome
        let start = startControl(in: mapApp)
        if start.exists { start.tap() }
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        try saveScreenshot(named: "ios-rehearse.png", of: mapApp)
        mapApp.terminate()

        // 3) Dispatch toast — peek sheet so top chrome stays visible; toast does not auto-dismiss under UITEST
        let toastApp = launchSeededApp(extra: ["UITEST_SEED_DISPATCH_TOAST", "UITEST_PEEK_SHEET"])
        toastApp.tap()
        dismissAlerts(in: toastApp)
        let toast = toastApp.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "dispatch")
        ).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 12), "Expected fleet dispatch toast")
        RunLoop.current.run(until: Date().addingTimeInterval(3)) // basemap tiles
        try saveScreenshot(named: "ios-dispatch-toast.png", of: toastApp)
    }

    @MainActor
    private func launchSeededApp(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_SKIP_AUTH",
            "UITEST_SKIP_ONBOARDING",
            "UITEST_SKIP_ROLE_PICKER",
            "UITEST_SEED_ROUTE",
            "UITEST_HGV_MODE",
        ]
        app.launchArguments += extra
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        return app
    }

    @MainActor
    private func dismissAlerts(in app: XCUIApplication) {
        if app.alerts.firstMatch.exists {
            let alert = app.alerts.firstMatch
            if alert.buttons["Allow While Using App"].exists {
                alert.buttons["Allow While Using App"].tap()
            } else if alert.buttons["Allow Once"].exists {
                alert.buttons["Allow Once"].tap()
            }
        }
    }

    @MainActor
    private func startControl(in app: XCUIApplication) -> XCUIElement {
        let nav = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start Navigation")).firstMatch
        if nav.exists { return nav }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start Simulation")).firstMatch
    }

    @MainActor
    private func waitForStartControl(in app: XCUIApplication) -> Bool {
        let nav = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start Navigation")).firstMatch
        if nav.waitForExistence(timeout: 25) { return true }
        let sim = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Start Simulation")).firstMatch
        return sim.waitForExistence(timeout: 10)
    }

    @MainActor
    private func saveScreenshot(named name: String, of app: XCUIApplication) throws {
        let shot = app.screenshot()
        let url = screenshotDir.appendingPathComponent(name)
        try shot.pngRepresentation.write(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Wrote \(name)")
    }
}
