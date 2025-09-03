import XCTest
@testable import SmartCellCounter

final class SettingsStoreTests: XCTestCase {
    func testClampAreaMinMax() async {
        let s = SettingsStore.shared
        s.areaMinUm2 = 1000
        s.areaMaxUm2 = 100
        // didSet clamps to ensure min <= max
        XCTAssertLessThanOrEqual(s.areaMinUm2, s.areaMaxUm2)
        s.areaMinUm2 = -10
        s.areaMaxUm2 = 2_000_000
        XCTAssertGreaterThanOrEqual(s.areaMinUm2, 1)
        XCTAssertLessThanOrEqual(s.areaMaxUm2, 1_000_000)
    }
}

