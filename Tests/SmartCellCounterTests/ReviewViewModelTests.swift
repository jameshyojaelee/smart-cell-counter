import XCTest
import CoreGraphics
@testable import SmartCellCounter

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testStatsCalculationUpdatesSelectionAndOutliers() {
        let viewModel = ReviewViewModel()
        let appState = AppState()

        appState.labeled = [
            makeLabeled(id: 1, label: "live", at: CGPoint(x: 10, y: 10)),
            makeLabeled(id: 2, label: "dead", at: CGPoint(x: 20, y: 20))
        ]
        viewModel.perSquare = [0: 100, 2: 110, 6: 105, 8: 420]
        viewModel.selectedLarge = [0, 2, 6, 8]

        viewModel.refreshStats(appState: appState)

        XCTAssertEqual(viewModel.stats.liveCount, 1)
        XCTAssertEqual(viewModel.stats.deadCount, 1)
        XCTAssertEqual(viewModel.stats.selectedSquareCount, 4)
        XCTAssertEqual(appState.selectedLargeSquares, [0, 2, 6, 8])
        XCTAssertGreaterThanOrEqual(viewModel.stats.outlierCount, 1)
        XCTAssertGreaterThan(viewModel.stats.averagePerSquare, 0)
    }

    func testLassoConfirmationAndUndoRestoresDetections() {
        let viewModel = ReviewViewModel()
        let appState = AppState()
        appState.labeled = [
            makeLabeled(id: 1, label: "live", at: CGPoint(x: 10, y: 10)),
            makeLabeled(id: 2, label: "dead", at: CGPoint(x: 60, y: 60)),
            makeLabeled(id: 3, label: "live", at: CGPoint(x: 15, y: 15))
        ]

        viewModel.lassoPath.move(to: CGPoint(x: 0, y: 0))
        viewModel.lassoPath.addLine(to: CGPoint(x: 40, y: 0))
        viewModel.lassoPath.addLine(to: CGPoint(x: 40, y: 40))
        viewModel.lassoPath.addLine(to: CGPoint(x: 0, y: 40))
        viewModel.lassoPath.closeSubpath()

        viewModel.prepareLassoConfirmation(in: appState)
        XCTAssertTrue(viewModel.showLassoConfirmation)
        XCTAssertEqual(viewModel.pendingRemovalIDs.count, 2)

        viewModel.confirmLassoRemoval(in: appState)
        XCTAssertEqual(appState.labeled.count, 1)
        XCTAssertTrue(viewModel.undoAvailable)

        viewModel.undoLastRemoval(in: appState)
        XCTAssertEqual(appState.labeled.count, 3)
    }

    private func makeLabeled(id: Int, label: String, at point: CGPoint) -> CellObjectLabeled {
        let cell = TestFixtures.cellObject(id: id, centroid: point)
        let stats = ColorSampleStats(hue: 0, saturation: 0, value: 0, L: 0, a: 0, b: 0)
        return CellObjectLabeled(id: id, base: cell, color: stats, label: label, confidence: 0.8)
    }
}
