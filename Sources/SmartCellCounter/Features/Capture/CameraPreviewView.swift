import SwiftUI
import Combine
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = context.coordinator.previewLayer {
            layer.frame = uiView.bounds
            if let conn = layer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var previewLayer: AVCaptureVideoPreviewLayer? }
}

@MainActor
final class CaptureViewModel: NSObject, ObservableObject, CameraServiceDelegate {
    let camera: CameraServicing
    @Published var focusScore: Double = 0
    @Published var glareRatio: Double = 0
    @Published var torchOn: Bool = false
    @Published var ready: Bool = false
    @Published var status: String = "Preparing…"
    @Published var permissionDenied: Bool = false
    @Published var navigatingToCrop = false
    @Published var previewEnabled: Bool = false
    private let capturedSubject = PassthroughSubject<UIImage, Never>()
    var captured: AnyPublisher<UIImage, Never> { capturedSubject.eraseToAnyPublisher() }

    override init() {
        self.camera = CameraService()
        super.init()
        camera.delegate = self
    }

    init(service: CameraServicing) {
        self.camera = service
        super.init()
        camera.delegate = self
    }

    func start() {
        if cancellables.isEmpty {
            camera.readinessPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isReady in self?.ready = isReady }
                .store(in: &cancellables)
            camera.statePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] st in
                    switch st {
                    case .idle: self?.status = "Idle"
                    case .preparing: self?.status = "Preparing…"
                    case .ready: self?.status = "Ready"
                    case .capturing: self?.status = "Capturing…"
                    case .saving: self?.status = "Saving…"
                    case .error(let err):
                        self?.status = err.localizedDescription
                        if case .permissionDenied = err { self?.permissionDenied = true } else { self?.permissionDenied = false }
                    }
                }
                .store(in: &cancellables)
        }
        camera.start()
    }
    func stop() { camera.stop() }
    func setTorch(enabled: Bool) {
        if torchOn != enabled { torchOn = enabled }
        camera.setTorch(enabled: enabled)
    }
    func capture() { camera.capturePhoto() }

    var captureSession: AVCaptureSession { camera.captureSession }

    // MARK: - CameraServiceDelegate
    func cameraService(_ service: CameraService, didUpdateFocusScore score: Double, glareRatio: Double) {
        self.focusScore = score
        self.glareRatio = glareRatio
    }

    func cameraService(_ service: CameraService, didCapture image: UIImage) {
        capturedSubject.send(image)
    }

    private var cancellables: Set<AnyCancellable> = []
}
