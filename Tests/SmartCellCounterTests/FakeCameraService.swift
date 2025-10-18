import Foundation
import AVFoundation
import Combine
import UIKit
@testable import SmartCellCounter

final class FakeCameraService: CameraServicing {
    weak var delegate: CameraServiceDelegate?
    let captureSession = AVCaptureSession()

    private let readinessSubject = PassthroughSubject<Bool, Never>()
    var readinessPublisher: AnyPublisher<Bool, Never> { readinessSubject.eraseToAnyPublisher() }

    private let stateSubject = PassthroughSubject<CameraState, Never>()
    var statePublisher: AnyPublisher<CameraState, Never> { stateSubject.eraseToAnyPublisher() }

    var permissionGranted: Bool
    var readyImmediately: Bool
    private(set) var torchEnabledHistory: [Bool] = []
    private(set) var focusPoints: [CGPoint] = []
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    init(permissionGranted: Bool = true, readyImmediately: Bool = true) {
        self.permissionGranted = permissionGranted
        self.readyImmediately = readyImmediately
    }

    func start() {
        startCount += 1
        if permissionGranted {
            stateSubject.send(.preparing)
            if readyImmediately {
                readinessSubject.send(true)
                stateSubject.send(.ready)
            }
        } else {
            stateSubject.send(.preparing)
            stateSubject.send(.error(.permissionDenied))
        }
    }

    func stop() {
        stopCount += 1
        stateSubject.send(.idle)
    }

    func capturePhoto() {
        stateSubject.send(.capturing)
        // Emit a tiny 1x1 image for tests
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let img = renderer.image { ctx in UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1)) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let stub = CameraService()
            self.delegate?.cameraService(stub, didCapture: img)
        }
    }

    func setTorch(enabled: Bool) {
        torchEnabledHistory.append(enabled)
    }

    func setFocusExposure(point: CGPoint) {
        focusPoints.append(point)
    }
}
