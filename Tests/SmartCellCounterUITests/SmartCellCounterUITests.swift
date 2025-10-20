import XCTest

final class SmartCellCounterUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testEndToEndMockedCaptureFlow() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-onboarding.completed", "1",
            "-consent.shown", "1",
            "-UITest.MockCapture", "1"
        ]
        app.launch()

        // Capture screen should show mocked image
        let captureTitle = app.staticTexts["Capture"]
        let captureNav = app.navigationBars["Capture"]
        XCTAssertTrue(captureTitle.waitForExistence(timeout: 5) || captureNav.waitForExistence(timeout: 5))

        let mockedPreview = app.images["mockCapturePreview"]
        XCTAssertTrue(mockedPreview.waitForExistence(timeout: 5))

        // Move forward to crop or review using mocked flow
        let shutterButton = app.buttons["Shutter"]
        if shutterButton.waitForExistence(timeout: 5) {
            shutterButton.tap()
        }

        // Crop view should auto-progress in mock mode, wait for Review
        let reviewTitle = app.navigationBars["Review"]
        let reviewLabel = app.staticTexts["Review"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 10) || reviewLabel.waitForExistence(timeout: 10))

        let detectionToggle = app.buttons["Detections"]
        if detectionToggle.waitForExistence(timeout: 5) {
            detectionToggle.tap()
        }

        // Swiping should not crash and mock counts are visible
        app.swipeUp()
        let countsLabel = app.staticTexts["Live / Dead"]
        XCTAssertTrue(countsLabel.waitForExistence(timeout: 5))

        // Navigate to Results tab for consistency
        app.tabBars.buttons["Results"].tap()
        XCTAssertTrue(app.staticTexts["Live / Dead"].waitForExistence(timeout: 5))
    }

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
