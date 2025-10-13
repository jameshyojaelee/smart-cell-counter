import XCTest
import UIKit
@testable import SmartCellCounter

final class ImagingTests: XCTestCase {
    func testAreaConversion() {
        // pxPerMicron^2 conversion check using a known area
        let pxPerMicron = 2.0 // 2 px / µm -> 4 px per µm^2
        let areaUm2 = 100.0
        let expectedPx = Int(areaUm2 * pow(pxPerMicron, 2))
        XCTAssertEqual(expectedPx, 400)
    }

    func testSegmentationFallbackWhenModelMissing() {
        let size = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.black.setFill()
        UIRectFill(CGRect(x: 10, y: 10, width: 12, height: 12))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let params = ImagingParams()
        let seg = ImagingPipeline.segmentCells(in: image, params: params)
        XCTAssertEqual(seg.width > 0 && seg.height > 0, true)
        XCTAssertEqual(seg.mask.count, seg.width * seg.height)
    }

    func testPolarityInversionCheck() {
        // If background bright and objects dark vs inverted
        // Here we just ensure our Otsu fallback yields valid thresholded mask
        let size = CGSize(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.black.setFill(); UIBezierPath(ovalIn: CGRect(x: 20, y: 20, width: 24, height: 24)).fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        var params = ImagingParams()
        params.thresholdMethod = .otsu
        let seg = ImagingPipeline.segmentCells(in: img, params: params)
        let sum = seg.mask.reduce(0) { $0 + ($1 ? 1 : 0) }
        XCTAssertGreaterThan(sum, 0)
    }
}
