import XCTest
@testable import SmartCellCounter
import UIKit

final class ImagingPipelineTests: XCTestCase {
    func testPolarityInversionCheck() throws {
        let white = Self.makeSolidImage(color: .white, size: CGSize(width: 32, height: 32))
        XCTAssertTrue(ImagingPipeline.shouldInvertPolarity(for: white))

        let black = Self.makeSolidImage(color: .black, size: CGSize(width: 32, height: 32))
        XCTAssertFalse(ImagingPipeline.shouldInvertPolarity(for: black))
    }

    func testAreaUnitConversion() throws {
        // 100 px with 2 px/µm -> 100 / 4 = 25 µm²
        let area = Hemocytometer.areaUm2(pixelCount: 100, pxPerMicron: 2.0)
        XCTAssertEqual(area, 25.0, accuracy: 0.0001)
    }

    func testSegmentationFallbackWhenModelMissing() throws {
        // Create simple synthetic image: black circle on white background
        let img = Self.makeCircleImage(size: CGSize(width: 64, height: 64), radius: 12)
        let params = ImagingParams()
        let seg = ImagingPipeline.segmentCells(in: img, params: params)
        XCTAssertTrue(seg.width > 0 && seg.height > 0)
        let fg = seg.mask.filter { $0 }.count
        XCTAssertGreaterThan(fg, 0, "Fallback segmentation should produce some foreground")
    }

    // MARK: - Helpers
    static func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    static func makeCircleImage(size: CGSize, radius: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.black.setFill()
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius*2, height: radius*2)
        UIBezierPath(ovalIn: rect).fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

