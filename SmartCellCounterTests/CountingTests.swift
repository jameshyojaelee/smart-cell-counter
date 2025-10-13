import XCTest
@testable import SmartCellCounter

final class CountingTests: XCTestCase {
    func testMapCentroidToGridRespectsBounds() {
        let geometry = GridGeometry(originPx: .zero, pxPerMicron: 1.0)
        let inside = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 50, y: 50), geometry: geometry)
        XCTAssertNotNil(inside)
        let outside = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 4000, y: 4000), geometry: geometry)
        XCTAssertNil(outside)
    }

    func testRobustInliersRejectsOutliers() {
        let values = [100.0, 102.0, 98.0, 300.0]
        let mask = CountingService.robustInliers(values, threshold: 2.5)
        XCTAssertEqual(mask.count, values.count)
        XCTAssertTrue(mask[0])
        XCTAssertFalse(mask[3])
    }

    func testConcentrationAndViability() {
        let concentration = CountingService.concentrationPerML(meanCountPerLargeSquare: 50, dilutionFactor: 2)
        XCTAssertEqual(concentration, 1_000_000, accuracy: 0.0001)
        let viability = CountingService.viabilityPercent(live: 80, dead: 20)
        XCTAssertEqual(viability, 80)
    }
}
