import XCTest
@testable import SmartCellCounter
import UIKit
import CoreImage

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

    func testSegmentationMetadataTracksDownscaleAndPolarity() {
        var params = ImagingParams()
        params.strategy = .classical
        params.thresholdMethod = .otsu
        let img = Self.makeCircleImage(size: CGSize(width: 1024, height: 1024), radius: 80)
        let seg = ImagingPipeline.segmentCells(in: img, params: params)
        XCTAssertGreaterThan(seg.downscaleFactor, 1.0)
        XCTAssertTrue(seg.polarityInverted)
        XCTAssertEqual(seg.usedStrategy, .classical)
        XCTAssertEqual(Int(seg.originalSize.width), 1024)
        XCTAssertEqual(Int(seg.originalSize.height), 1024)
    }

    func testCoreMLStrategyFallsBackWhenModelMissing() {
        var params = ImagingParams()
        params.strategy = .coreML
        let img = Self.makeCircleImage(size: CGSize(width: 128, height: 128), radius: 32)
        let seg = ImagingPipeline.segmentCells(in: img, params: params)
        if ImagingPipeline.isCoreMLSegmentationAvailable {
            XCTAssertEqual(seg.usedStrategy, .coreML)
        } else {
            XCTAssertEqual(seg.usedStrategy, .classical)
        }
        XCTAssertTrue(seg.width > 0)
        XCTAssertTrue(seg.height > 0)
    }

    func testObjectFeaturesPerimeterCountsAllEdges() throws {
        let mask: [Bool] = [
            true, true, false,
            true, true, false,
            false, false, false
        ]
        let seg = SegmentationResult(width: 3, height: 3, mask: mask)
        let objects = ImagingPipeline.objectFeatures(from: seg, pxPerMicron: nil)
        XCTAssertEqual(objects.count, 1)
        let object = try XCTUnwrap(objects.first)
        XCTAssertEqual(object.pixelCount, 4)
        XCTAssertEqual(object.perimeterPx, 8)
        let expectedCircularity = (4.0 * Double.pi * object.areaPx) / (object.perimeterPx * object.perimeterPx)
        XCTAssertEqual(object.circularity, expectedCircularity, accuracy: 1e-9)
    }

    func testHueMaskSupportsWrapAround() {
        let extent = CGRect(x: 0, y: 0, width: 1, height: 1)
        let hueHigh = CIImage(color: CIColor(red: 0.99, green: 0, blue: 0)).cropped(to: extent) // ~356°
        let hueMid = CIImage(color: CIColor(red: 0.5, green: 0, blue: 0)).cropped(to: extent)  // 180°
        let sat = CIImage(color: CIColor(red: 0.6, green: 0, blue: 0)).cropped(to: extent)
        let val = CIImage(color: CIColor(red: 0.4, green: 0, blue: 0)).cropped(to: extent)
        let hsvHigh = HSVImage(h: hueHigh, s: sat, value: val)
        let hsvMid = HSVImage(h: hueMid, s: sat, value: val)
        let ctx = CIContext()
        let maskHigh = BlueMask.mask(fromHSV: hsvHigh, hueMin: 350, hueMax: 10, minS: 0.3, maxV: 0.8, context: ctx)
        let maskMid = BlueMask.mask(fromHSV: hsvMid, hueMin: 350, hueMax: 10, minS: 0.3, maxV: 0.8, context: ctx)

        XCTAssertTrue(pixelIsSet(maskHigh, context: ctx))
        XCTAssertFalse(pixelIsSet(maskMid, context: ctx))
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

private func pixelIsSet(_ image: CIImage, context: CIContext) -> Bool {
    var pixel = [UInt8](repeating: 0, count: 4)
    context.render(
        image,
        toBitmap: &pixel,
        rowBytes: 4,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBA8,
        colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    return pixel[0] > 0 || pixel[1] > 0 || pixel[2] > 0
}
