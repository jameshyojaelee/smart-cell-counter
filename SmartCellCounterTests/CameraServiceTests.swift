import XCTest
import AVFoundation
import UIKit
@testable import SmartCellCounter

final class CameraServiceTests: XCTestCase {
    func testGlareRatioReflectsBrightness() throws {
        let brightBuffer = try TestFixtures.sampleBuffer(width: 8, height: 8, color: .white)
        let darkBuffer = try TestFixtures.sampleBuffer(width: 8, height: 8, color: .black)
        let service = CameraService()
        let delegate = RecordingDelegate()
        service.delegate = delegate
        let output = AVCaptureVideoDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)

        let brightExpectation = expectation(description: "Bright glare")
        delegate.onUpdate = { _, glare in
            if glare > 0.8 {
                brightExpectation.fulfill()
            }
        }
        service.captureOutput(output, didOutput: brightBuffer, from: connection)
        wait(for: [brightExpectation], timeout: 1.0)
        let brightGlare = delegate.lastGlare ?? 0
        XCTAssertGreaterThan(brightGlare, 0.8)

        let darkExpectation = expectation(description: "Dark glare")
        delegate.onUpdate = { _, glare in
            if glare < 0.1 {
                darkExpectation.fulfill()
            }
        }
        service.captureOutput(output, didOutput: darkBuffer, from: connection)
        wait(for: [darkExpectation], timeout: 1.0)
        let darkGlare = delegate.lastGlare ?? 1
        XCTAssertLessThan(darkGlare, 0.1)
    }
}

private final class RecordingDelegate: CameraServiceDelegate {
    var lastGlare: Double?
    var onUpdate: ((Double, Double) -> Void)?

    func cameraService(_ service: CameraService, didUpdateFocusScore score: Double, glareRatio: Double) {
        lastGlare = glareRatio
        onUpdate?(score, glareRatio)
    }

    func cameraService(_ service: CameraService, didCapture image: UIImage) {}
}
