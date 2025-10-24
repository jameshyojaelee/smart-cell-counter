import XCTest
@testable import SmartCellCounter

final class GeometryUtilsTests: XCTestCase {
    func testClampRect() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        let r = CGRect(x: -10, y: -10, width: 220, height: 120)
        let clamped = GeometryUtils.clamp(r, to: bounds)
        XCTAssertEqual(clamped.origin.x, 0)
        XCTAssertEqual(clamped.origin.y, 0)
        XCTAssertLessThanOrEqual(clamped.maxX, bounds.maxX)
        XCTAssertLessThanOrEqual(clamped.maxY, bounds.maxY)
    }

    func testScaleRect() {
        let src = CGSize(width: 100, height: 50)
        let dst = CGSize(width: 200, height: 100)
        let r = CGRect(x: 10, y: 5, width: 20, height: 10)
        let scaled = GeometryUtils.scale(rect: r, from: src, to: dst)
        XCTAssertEqual(scaled, CGRect(x: 20, y: 10, width: 40, height: 20))
    }
}
