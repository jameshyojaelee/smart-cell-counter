import Foundation
import AVFoundation
import Combine
import UIKit

public enum CameraState: Equatable {
    case idle
    case preparing
    case ready
    case capturing
    case saving
    case error(AppError)
}

public protocol CameraServicing: AnyObject {
    var delegate: CameraServiceDelegate? { get set }
    var captureSession: AVCaptureSession { get }
    var readinessPublisher: AnyPublisher<Bool, Never> { get }
    var statePublisher: AnyPublisher<CameraState, Never> { get }

    func start()
    func stop()
    func capturePhoto()
    func setTorch(enabled: Bool)
    func setFocusExposure(point: CGPoint)
}
