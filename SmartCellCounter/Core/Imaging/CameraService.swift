import Foundation
import AVFoundation
import UIKit
import CoreImage
import Combine

public protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didUpdateFocusScore score: Double, glareRatio: Double)
    func cameraService(_ service: CameraService, didCapture image: UIImage)
}

public final class CameraService: NSObject {
    public enum State: Equatable { case idle, preparing, ready, capturing, saving, error(AppError) }

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private let ciContext = ImageContext.ciContext

    public weak var delegate: CameraServiceDelegate?
    public var captureSession: AVCaptureSession { session }
    private(set) var isReady: Bool = false { didSet { readinessSubject.send(isReady) } }
    private let readinessSubject = PassthroughSubject<Bool, Never>()
    public var readinessPublisher: AnyPublisher<Bool, Never> { readinessSubject.eraseToAnyPublisher() }
    private let stateSubject = CurrentValueSubject<State, Never>(.idle)
    public var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }

    public func start() {
        stateSubject.send(.preparing)
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        if auth == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.startSessionOnQueue() }
                    else { self.stateSubject.send(.error(.permissionDenied)) }
                }
            }
        } else if auth == .authorized {
            startSessionOnQueue()
        } else {
            Logger.log("Camera permission not granted")
            stateSubject.send(.error(.permissionDenied))
        }
    }

    private func startSessionOnQueue() {
        queue.async {
            do {
                try self.configureSession()
                self.session.startRunning()
                let hasConnection = (self.photoOutput.connection(with: .video) != nil)
                DispatchQueue.main.async {
                    self.isReady = self.session.isRunning && hasConnection
                    self.stateSubject.send(self.isReady ? .ready : .error(.hardwareUnavailable))
                }
            } catch {
                DispatchQueue.main.async { self.stateSubject.send(.error(.configurationFailed(error.localizedDescription))) }
            }
        }
    }

    public func stop() {
        queue.async {
            self.session.stopRunning()
        }
    }

    public func capturePhoto() {
        queue.async {
            guard self.session.isRunning,
                  let conn = self.photoOutput.connection(with: .video), conn.isEnabled else {
                Logger.log("Capture requested before session ready; ignoring")
                DispatchQueue.main.async { self.stateSubject.send(.error(.notReady)) }
                return
            }
            DispatchQueue.main.async { self.stateSubject.send(.capturing) }
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = self.photoOutput.isHighResolutionCaptureEnabled
            self.captureStart = Date()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    public func setFocusExposure(point: CGPoint) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
            if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
            if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
            device.unlockForConfiguration()
        } catch {
            Logger.log("Camera config error: \(error)")
        }
    }

    public func lockFocusAndExposure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) {
                if #available(iOS 13.0, *) {
                    try? device.setFocusModeLocked(lensPosition: device.lensPosition)
                } else {
                    device.focusMode = .locked
                }
            }
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            device.unlockForConfiguration()
        } catch {
            Logger.log("Lock focus/exposure error: \(error)")
        }
    }

    public func unlockFocusAndExposure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
            device.unlockForConfiguration()
        } catch {
            Logger.log("Unlock focus/exposure error: \(error)")
        }
    }

    public func setTorch(enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            Logger.log("Torch error: \(error)")
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration(); throw AppError.hardwareUnavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) } else { throw AppError.configurationFailed("Cannot add camera input") }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        } else { throw AppError.configurationFailed("Cannot add photo output") }
        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }
}

private var captureStartKey: UInt8 = 0
extension CameraService {
    private var captureStart: Date? {
        get { objc_getAssociatedObject(self, &captureStartKey) as? Date }
        set { objc_setAssociatedObject(self, &captureStartKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { Logger.log("Photo capture error: \(error)"); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        if let start = captureStart { PerformanceLogger.shared.record("capture", Date().timeIntervalSince(start) * 1000) }
        delegate?.cameraService(self, didCapture: image)
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Approximate focus score using Laplacian response mean
        let focusScore = laplacianMean(ciImage)
        // Approximate glare ratio by counting near-white pixels via histogram
        let glare = glareRatio(ciImage)
        DispatchQueue.main.async {
            self.delegate?.cameraService(self, didUpdateFocusScore: focusScore, glareRatio: glare)
        }
    }

    private func laplacianMean(_ image: CIImage) -> Double {
        let kernel: [CGFloat] = [0,1,0, 1,-4,1, 0,1,0]
        let filter = CIFilter(name: "CIConvolution3X3", parameters: [kCIInputImageKey: image, "inputWeights": CIVector(values: kernel, count: 9), "inputBias": 0])
        guard let out = filter?.outputImage else { return 0 }
        let extent = out.extent
        let avg = out.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(avg, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Use luminance of avg response as proxy
        let r = Double(bitmap[0])/255.0, g = Double(bitmap[1])/255.0, b = Double(bitmap[2])/255.0
        return 0.2126*r + 0.7152*g + 0.0722*b
    }

    private func glareRatio(_ image: CIImage) -> Double {
        let hist = image.applyingFilter("CIAreaHistogram", parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent), "inputCount": 64])
        var data = [UInt8](repeating: 0, count: 64*4)
        ciContext.render(hist, toBitmap: &data, rowBytes: 64*4, bounds: CGRect(x: 0, y: 0, width: 64, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        var sumAll = 0.0
        var sumBright = 0.0
        for i in stride(from: 0, to: data.count, by: 4) {
            let count = Double(UInt32(data[i]) | (UInt32(data[i+1])<<8) | (UInt32(data[i+2])<<16) | (UInt32(data[i+3])<<24))
            sumAll += count
            if i/4 >= 56 { sumBright += count } // top ~12.5%
        }
        if sumAll == 0 { return 0 }
        return sumBright / sumAll
    }
}
