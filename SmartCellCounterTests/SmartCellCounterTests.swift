import XCTest
import Combine
@testable import SmartCellCounter

@MainActor
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

    func testHemocytometerFormulas() throws {
        // Concentration: 25 avg cells/square with 2x dilution => 25 * 10^4 * 2 = 500,000
        let concentration = Hemocytometer.concentration(avgCellsPerSquare: 25, dilutionFactor: 2)
        XCTAssertEqual(concentration, 500_000, accuracy: 0.0001)

        // Viability: 170 live, 30 dead => 170/200 * 100 = 85%
        let viability = Hemocytometer.viability(live: 170, dead: 30)
        XCTAssertEqual(viability, 85.0, accuracy: 0.0001)
    }
}
