@testable import SmartCellCounter
import UIKit
import XCTest

final class ImagingTests: XCTestCase {
    func testAreaConversionMatchesHemocytometer() {
        let pxPerMicron = 2.0 // 2 px / µm
        let pixelCount = 400
        let areaUm2 = Hemocytometer.areaUm2(pixelCount: pixelCount, pxPerMicron: pxPerMicron)
        XCTAssertEqual(areaUm2, 100, accuracy: 1e-6)
        let roundTrip = Int(areaUm2 * pow(pxPerMicron, 2))
        XCTAssertEqual(roundTrip, pixelCount)
    }

    func testSegmentationFallbackWhenModelMissingUsesClassicalPath() {
        let circle = TestFixtures.circleImage(size: CGSize(width: 48, height: 48),
                                              circleRect: CGRect(x: 18, y: 18, width: 12, height: 12),
                                              fill: .black,
                                              background: .white)
        var params = ImagingParams()
        params.thresholdMethod = .otsu
        let seg = ImagingPipeline.segmentCells(in: circle, params: params)
        XCTAssertTrue(seg.width > 0 && seg.height > 0)
        XCTAssertEqual(seg.mask.count, seg.width * seg.height)
        let foregroundCount = seg.mask.filter { $0 }.count
        XCTAssertGreaterThan(foregroundCount, 0, "Classical segmentation should mark the synthetic cell foreground.")
        XCTAssertEqual(seg.usedStrategy, .classical)
    }

    func testSegmentationFeedsObjectFeatures() {
        let circle = TestFixtures.circleImage(size: CGSize(width: 64, height: 64),
                                              circleRect: CGRect(x: 24, y: 24, width: 16, height: 16),
                                              fill: .black,
                                              background: .white)
        let seg = ImagingPipeline.segmentCells(in: circle, params: ImagingParams())
        let objects = ImagingPipeline.objectFeatures(from: seg, pxPerMicron: nil)
        XCTAssertFalse(objects.isEmpty)
        let object = try? XCTUnwrap(objects.first)
        XCTAssertGreaterThan(object?.pixelCount ?? 0, 0)
        XCTAssertGreaterThan(object?.perimeterPx ?? 0, 0)
    }

    func testPolarityInversionCheck() {
        let bright = TestFixtures.solidImage(color: .white, size: CGSize(width: 32, height: 32))
        XCTAssertTrue(ImagingPipeline.shouldInvertPolarity(for: bright))

        let dark = TestFixtures.solidImage(color: .black, size: CGSize(width: 32, height: 32))
        XCTAssertFalse(ImagingPipeline.shouldInvertPolarity(for: dark))
    }
}
