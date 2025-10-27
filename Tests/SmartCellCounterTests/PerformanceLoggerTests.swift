@testable import SmartCellCounter
import XCTest

final class PerformanceLoggerTests: XCTestCase {
    private let testDeviceInfo = PerformanceLogger.DeviceInfo(
        deviceModel: "TestDevice",
        systemName: "TestOS",
        systemVersion: "1.0",
        appVersion: "1.0",
        localeIdentifier: "en_US",
        hardwareIdentifier: "TestBoard"
    )

    func testRollingAveragesRespectWindow() {
        let logger = PerformanceLogger(windowSize: 3, deviceInfoProvider: { self.testDeviceInfo })
        defer { logger.reset() }

        logger.record("demo", 10)
        logger.record("demo", 20)
        logger.record("demo", 30)
        logger.record("demo", 40)
        logger.record("demo", 50)

        let snapshot = logger.metricsSnapshot()
        guard let metric = snapshot.metrics.first(where: { $0.label == "demo" }) else {
            return XCTFail("Metric not recorded")
        }

        XCTAssertEqual(metric.sampleCount, 5)
        XCTAssertEqual(metric.recentSampleCount, 3)
        XCTAssertEqual(metric.rollingAverage, (30 + 40 + 50) / 3, accuracy: 0.001)
        XCTAssertEqual(metric.overallAverage, (10 + 20 + 30 + 40 + 50) / 5, accuracy: 0.001)
        XCTAssertEqual(metric.recentMin, 30.0, accuracy: 0.001)
        XCTAssertEqual(metric.recentMax, 50.0, accuracy: 0.001)
    }

    func testStageRecordingCapturesSamples() {
        let logger = PerformanceLogger(windowSize: 5, deviceInfoProvider: { self.testDeviceInfo })
        defer { logger.reset() }

        logger.record(stage: .capture, duration: 12.5, metadata: ["mode": "unit-test"])
        logger.record(stage: .capture, duration: 15.0, metadata: ["mode": "unit-test"])
        logger.record(stage: .segmentation, duration: 42.0, metadata: ["used": "classical"])

        let snapshot = logger.metricsSnapshot()
        guard let captureMetric = snapshot.metrics.first(where: { $0.label == PerformanceLogger.Stage.capture.rawValue }) else {
            return XCTFail("Capture metric missing")
        }
        XCTAssertEqual(captureMetric.sampleCount, 2)
        XCTAssertEqual(captureMetric.rollingAverage, (12.5 + 15.0) / 2, accuracy: 0.001)

        let samples = logger.recentSamples()
        XCTAssertEqual(samples.count, 3)
        let first = samples.first(where: { $0.label == PerformanceLogger.Stage.capture.rawValue })
        XCTAssertEqual(first?.stage, .capture)
        XCTAssertEqual(first?.metadata["mode"], "unit-test")
        XCTAssertEqual(first?.deviceInfo, testDeviceInfo)

        let limited = logger.recentSamples(limit: 1)
        XCTAssertEqual(limited.count, 1)
    }
}
