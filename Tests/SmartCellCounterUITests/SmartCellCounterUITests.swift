import XCTest

final class SmartCellCounterUITests: XCTestCase {
    func testScreenshots() throws {
        throw XCTSkip("Screenshot flow is manual-only; skipping in automated test run.")
        let app = XCUIApplication()
        app.launch()

        // Capture
        takeShot(app, name: "01_capture")

        // Results
        app.tabBars.buttons["Results"].tap()
        takeShot(app, name: "02_results")

        // Review (use Results as proxy overlay)
        app.tabBars.buttons["Results"].tap()
        takeShot(app, name: "03_review")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        takeShot(app, name: "04_settings")
    }

    func testDynamicTypeScalingOnResults() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-onboarding.completed", "1",
            "-consent.shown", "1"
        ]
        app.launch()

        // Dismiss onboarding or consent if arguments fail
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) { skipButton.tap() }
        let continueConsent = app.buttons["Continue"]
        if continueConsent.waitForExistence(timeout: 2) { continueConsent.tap() }

        let resultsTab = app.tabBars.buttons["Results"]
        XCTAssertTrue(resultsTab.waitForExistence(timeout: 5), "Results tab should exist")
        resultsTab.tap()

        let squaresLabel = app.staticTexts["Squares Used"]
        XCTAssertTrue(squaresLabel.waitForExistence(timeout: 5), "Squares Used label should be visible under large Dynamic Type")

        let exportButton = app.buttons["Export CSV"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export CSV button should be present")
        if !exportButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(exportButton.isHittable, "Export CSV button should remain tappable at large text sizes")

        let saveSampleButton = app.buttons["Save Sample"]
        XCTAssertTrue(saveSampleButton.waitForExistence(timeout: 5), "Save Sample button should be present")
        if !saveSampleButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(saveSampleButton.isHittable, "Save Sample button should remain tappable at large text sizes")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.lifetime = .keepAlways
        attachment.name = name
        add(attachment)
    }
}
