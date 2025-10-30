@testable import SmartCellCounter
import XCTest

final class CountingTests: XCTestCase {
    func testMapCentroidToGridRespectsBounds() {
        let geometry = GridGeometry(originPx: .zero, pxPerMicron: 1.0)
        let inside = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 50, y: 50), geometry: geometry)
        XCTAssertNotNil(inside)
        let outside = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 4000, y: 4000), geometry: geometry)
        XCTAssertNil(outside)
    }

    func testTallyByLargeSquareAggregatesCounts() {
        let geometry = GridGeometry(originPx: .zero, pxPerMicron: 1.0)
        let objects = [
            TestFixtures.cellObject(id: 1, centroid: CGPoint(x: 120, y: 120)), // large index 0
            TestFixtures.cellObject(id: 2, centroid: CGPoint(x: 1000, y: 140)), // boundary x=1000 -> still large index 0
            TestFixtures.cellObject(id: 3, centroid: CGPoint(x: 2100, y: 140)), // large index 2
            TestFixtures.cellObject(id: 4, centroid: CGPoint(x: 2180, y: 1140)), // large index 5
            TestFixtures.cellObject(id: 5, centroid: CGPoint(x: 2180, y: 2140)) // large index 8
        ]

        let tally = CountingService.tallyByLargeSquare(objects: objects, geometry: geometry)
        XCTAssertEqual(tally[0], 2, "Top-left large square should count both objects including boundary inclusion.")
        XCTAssertEqual(tally[2], 1)
        XCTAssertEqual(tally[5], 1)
        XCTAssertEqual(tally[8], 1)
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
