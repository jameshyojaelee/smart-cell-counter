import XCTest
import Combine
@testable import SmartCellCounter

final class SmartCellCounterTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testAppStatePublishesChanges() throws {
        let appState = AppState()
        let expectation = expectation(description: "AppState publishes lastAction changes")

        var received: String?
        appState.$lastAction
            .dropFirst() // Ignore initial value
            .sink { value in
                received = value
                expectation.fulfill()
            }
            .store(in: &cancellables)

        appState.lastAction = "capture"

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(received, "capture")
    }
}
