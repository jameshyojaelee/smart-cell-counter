import XCTest
@testable import SmartCellCounter

final class CountingTests: XCTestCase {
    func testInclusionRule() {
        XCTAssertTrue(CountingService.inclusionRule(x: 1, y: 1, left: 0, top: 0, right: 10, bottom: 10))
        XCTAssertFalse(CountingService.inclusionRule(x: 10, y: 5, left: 0, top: 0, right: 10, bottom: 10))
        XCTAssertFalse(CountingService.inclusionRule(x: 5, y: 10, left: 0, top: 0, right: 10, bottom: 10))
    }

    func testMADRejection() {
        let counts = [100, 102, 98, 300]
        let res = CountingService.MADOutlierReject(counts: counts)
        XCTAssertTrue(res.rejected.contains(300))
        XCTAssertEqual(res.kept.count, 3)
    }

    func testConcentrationAndViability() {
        let conc = CountingService.concentrationPerMl(meanCountPerLargeSquare: 50, dilutionFactor: 2)
        XCTAssertEqual(conc, 50 * 10000 * 2)
        let viab = CountingService.viabilityPercent(live: 80, dead: 20)
        XCTAssertEqual(viab, 80)
    }
}
