import AVFoundation
import Combine
import CoreImage
import Foundation
import UIKit

@MainActor
public protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didUpdateFocusScore score: Double, glareRatio: Double)
    func cameraService(_ service: CameraService, didCapture image: UIImage)
}

public final class CameraService: NSObject, CameraServicing {
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
    private let stateSubject = CurrentValueSubject<CameraState, Never>(.idle)
    public var statePublisher: AnyPublisher<CameraState, Never> { stateSubject.eraseToAnyPublisher() }

    public func start() {
        stateSubject.send(.preparing)
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        if auth == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.startSessionOnQueue() } else { self.stateSubject.send(.error(.permissionDenied)) }
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
            DispatchQueue.main.async {
                self.isReady = false
                self.stateSubject.send(.idle)
            }
        }
    }

    public func capturePhoto() {
        queue.async {
            guard self.session.isRunning,
                  let conn = self.photoOutput.connection(with: .video), conn.isEnabled
            else {
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
        queue.async {
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
        queue.async {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = enabled ? .on : .off
                device.unlockForConfiguration()
            } catch {
                Logger.log("Torch error: \(error)")
            }
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
    public func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { Logger.log("Photo capture error: \(error)"); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        if let start = captureStart {
            let ms = Date().timeIntervalSince(start) * 1000
            PerformanceLogger.shared.record(stage: .capture, duration: ms, metadata: ["mode": "photo"])
            PerformanceLogger.shared.record("capture", ms)
        }
        DispatchQueue.main.async {
            self.delegate?.cameraService(self, didCapture: image)
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
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
        let kernel: [CGFloat] = [0, 1, 0, 1, -4, 1, 0, 1, 0]
        let filter = CIFilter(name: "CIConvolution3X3", parameters: [kCIInputImageKey: image, "inputWeights": CIVector(values: kernel, count: 9), "inputBias": 0])
        guard let out = filter?.outputImage else { return 0 }
        let extent = out.extent
        let avg = out.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(avg, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Use luminance of avg response as proxy
        let r = Double(bitmap[0]) / 255.0, g = Double(bitmap[1]) / 255.0, b = Double(bitmap[2]) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func glareRatio(_ image: CIImage) -> Double {
        let bins = 64
        let histogram = image.applyingFilter(
            "CIAreaHistogram",
            parameters: [
                kCIInputExtentKey: CIVector(cgRect: image.extent),
                "inputCount": bins,
                "inputScale": 1.0
            ]
        )
        var data = [Float](repeating: 0, count: bins * 4)
        let rowBytes = bins * 4 * MemoryLayout<Float>.size
        ciContext.render(
            histogram,
            toBitmap: &data,
            rowBytes: rowBytes,
            bounds: CGRect(x: 0, y: 0, width: bins, height: 1),
            format: .RGBAf,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        var total: Float = 0
        var bright: Float = 0
        let brightStart = Int(Double(bins) * 0.875) // top ~12.5%
        for bin in 0 ..< bins {
            let count = data[bin * 4]
            total += count
            if bin >= brightStart {
                bright += count
            }
        }
        guard total > 0 else { return 0 }
        return Double(bright / total)
    }
}
