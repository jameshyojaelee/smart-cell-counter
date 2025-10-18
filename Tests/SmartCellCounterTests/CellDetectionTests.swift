import XCTest
import CoreImage
@testable import SmartCellCounter

final class CellDetectionTests: XCTestCase {
    private let context = CIContext()

    func testClassifierMarksBlueCandidateAsDead() throws {
        let size = CGSize(width: 32, height: 32)
        let deadCenter = CGPoint(x: 8, y: 8)
        let blueMask = TestFixtures.constantCIImage(value: 1, size: size)
        let emptyMask = TestFixtures.constantCIImage(value: 0, size: size)
        let params = DetectorParams(enableGridSuppression: false,
                                    blueHueMin: 200,
                                    blueHueMax: 260,
                                    minBlueSaturation: 0.3,
                                    blobScoreThreshold: 0.4,
                                    nmsIoU: 0.3,
                                    minCellDiameterUm: 5,
                                    maxCellDiameterUm: 40)
        let candidates = [Candidate(center: deadCenter, radius: 5, score: 0.9)]
        let hsv = HSVImage.constant(hue: 220, saturation: 0.6, value: 0.3, size: size)
        let results = Classifier.classify(candidates: candidates,
                                          hsv: hsv,
                                          blueMask: blueMask,
                                          gridMask: emptyMask,
                                          eqLuma: emptyMask,
                                          context: context,
                                          params: params)
        XCTAssertEqual(results.count, 1)
        let dead = try XCTUnwrap(results.first)
        XCTAssertEqual(dead.label, "dead")
        XCTAssertGreaterThan(dead.confidence, 0.6)
    }

    func testClassifierMarksNonBlueCandidateAsLive() throws {
        let size = CGSize(width: 16, height: 16)
        let center = CGPoint(x: 8, y: 8)
        let mask = TestFixtures.constantCIImage(value: 0, size: size)
        let hsv = HSVImage.constant(hue: 120, saturation: 0.2, value: 0.7, size: size)
        let params = DetectorParams(enableGridSuppression: false,
                                    blueHueMin: 200,
                                    blueHueMax: 260,
                                    minBlueSaturation: 0.3,
                                    blobScoreThreshold: 0.4,
                                    nmsIoU: 0.3,
                                    minCellDiameterUm: 5,
                                    maxCellDiameterUm: 40)
        let result = Classifier.classify(candidates: [Candidate(center: center, radius: 4, score: 0.8)],
                                         hsv: hsv,
                                         blueMask: mask,
                                         gridMask: mask,
                                         eqLuma: mask,
                                         context: context,
                                         params: params)
        let candidate = try XCTUnwrap(result.first)
        XCTAssertEqual(candidate.label, "live")
        XCTAssertGreaterThan(candidate.confidence, 0.7)
    }
}

private extension HSVImage {
    static func constant(hue: Double, saturation: Double, value: Double, size: CGSize) -> HSVImage {
        let rect = CGRect(origin: .zero, size: size)
        let h = CIImage(color: CIColor(red: CGFloat(hue/360.0), green: 0, blue: 0, alpha: 1)).cropped(to: rect)
        let s = CIImage(color: CIColor(red: CGFloat(saturation), green: 0, blue: 0, alpha: 1)).cropped(to: rect)
        let v = CIImage(color: CIColor(red: CGFloat(value), green: 0, blue: 0, alpha: 1)).cropped(to: rect)
        return HSVImage(h: h, s: s, value: v)
    }
}
