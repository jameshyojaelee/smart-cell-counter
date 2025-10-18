import XCTest

final class SmartCellCounterUITests: XCTestCase {
    func testScreenshots() throws {
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

    private func takeShot(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.lifetime = .keepAlways
        attachment.name = name
        add(attachment)
    }
}
