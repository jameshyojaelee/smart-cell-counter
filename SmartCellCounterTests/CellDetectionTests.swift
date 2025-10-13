import XCTest
@testable import SmartCellCounter
import UIKit

@MainActor
final class CellDetectionTests: XCTestCase {
    func testBlankControlHasNoDetections() {
        guard let img = TestAssets.image(named: "blank_control") else { return }
        let store = SettingsStore.shared
        let params = DetectorParams.from(store)
        let det = CellDetector.detect(on: img, roi: nil, pxPerMicron: nil, params: params)
        XCTAssertLessThan(det.labeled.count, 3, "Should not detect circles on blank background")
    }

    func testBlueDeadClassification() {
        guard let img = TestAssets.image(named: "blue_dead_sample") else { return }
        let store = SettingsStore.shared
        let params = DetectorParams.from(store)
        let det = CellDetector.detect(on: img, roi: nil, pxPerMicron: nil, params: params)
        let dead = det.labeled.filter { $0.label == "dead" }.count
        XCTAssertGreaterThan(dead, 5)
    }

    func testPrecisionRecallOnGoldens() {
        guard let img = TestAssets.image(named: "golden01"),
              let truth = TestAssets.labels(named: "golden01") else { return }
        let store = SettingsStore.shared
        let params = DetectorParams.from(store)
        let det = CellDetector.detect(on: img, roi: nil, pxPerMicron: nil, params: params)
        let m = Metrics.precisionRecallF1(pred: det.labeled, truth: truth, iou: 0.3)
        XCTAssertGreaterThanOrEqual(m.p, 0.9, "precision")
        XCTAssertGreaterThanOrEqual(m.r, 0.85, "recall")
    }
}

enum TestAssets {
    static func image(named: String) -> UIImage? {
        let bundle = Bundle(for: CellDetectionTests.self)
        guard let url = bundle.url(forResource: named, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    static func labels(named: String) -> [LabeledPoint]? {
        let bundle = Bundle(for: CellDetectionTests.self)
        guard let url = bundle.url(forResource: named, withExtension: "json") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LabeledPoint].self, from: data)
    }
}

