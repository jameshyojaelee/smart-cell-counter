import XCTest
@testable import SmartCellCounter

final class DebugViewTests: XCTestCase {
    func testDebugViewEmbedsPerformanceDashboardView() throws {
        let fileURL = URL(fileURLWithPath: #file)
        let projectRoot = fileURL
            .deletingLastPathComponent() // DebugViewTests.swift
            .deletingLastPathComponent() // SmartCellCounterTests
            .deletingLastPathComponent() // Tests
        let debugViewPath = projectRoot.appendingPathComponent("Sources/SmartCellCounter/Features/Debug/DebugView.swift")
        let contents = try String(contentsOf: debugViewPath)
        XCTAssertTrue(contents.contains("PerformanceDashboardView"),
                      "DebugView.swift should reference PerformanceDashboardView")
    }

    func testPerformanceDashboardViewCanRenderWithoutMetrics() {
        XCTAssertNoThrow({
            _ = PerformanceDashboardView().body
        }())
    }
}
