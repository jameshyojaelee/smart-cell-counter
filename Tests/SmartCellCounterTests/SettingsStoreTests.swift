import XCTest
@testable import SmartCellCounter

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testClampAreaMinMax() async {
        let s = SettingsStore.shared
        defer { s.reset() }
        s.areaMinUm2 = 1000
        s.areaMaxUm2 = 100
        // didSet clamps to ensure min <= max
        XCTAssertLessThanOrEqual(s.areaMinUm2, s.areaMaxUm2)
        s.areaMinUm2 = -10
        s.areaMaxUm2 = 2_000_000
        XCTAssertGreaterThanOrEqual(s.areaMinUm2, 1)
        XCTAssertLessThanOrEqual(s.areaMaxUm2, 1_000_000)
    }

    func testHueBoundsStayOrdered() {
        let s = SettingsStore.shared
        defer { s.reset() }
        s.blueHueMax = 40
        s.blueHueMin = 340 // should clamp to current max
        XCTAssertLessThanOrEqual(s.blueHueMin, s.blueHueMax)
        s.blueHueMin = -10
        XCTAssertGreaterThanOrEqual(s.blueHueMin, 0)
        s.blueHueMax = 400
        XCTAssertLessThanOrEqual(s.blueHueMax, 360)
    }

    func testDiameterOrdering() {
        let s = SettingsStore.shared
        defer { s.reset() }
        s.maxCellDiameterUm = 20
        s.minCellDiameterUm = 50 // clamps down to current max
        XCTAssertLessThanOrEqual(s.minCellDiameterUm, s.maxCellDiameterUm)
        s.maxCellDiameterUm = 0 // minimum enforced
        XCTAssertGreaterThanOrEqual(s.maxCellDiameterUm, s.minCellDiameterUm)
    }

    func testBlockSizeNormalization() {
        let s = SettingsStore.shared
        defer { s.reset() }
        s.blockSize = 40
        XCTAssertEqual(s.blockSize, 41)
        s.blockSize = 130
        XCTAssertEqual(s.blockSize, 101)
    }

    func testSegmentationStrategyPersistsAndResets() {
        let s = SettingsStore.shared
        defer { s.reset() }
        s.segmentationStrategy = .coreML
        XCTAssertEqual(s.segmentationStrategy, .coreML)
        s.reset()
        XCTAssertEqual(s.segmentationStrategy, .automatic)
    }
}
