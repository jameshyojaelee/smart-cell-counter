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
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var previewLayer: AVCaptureVideoPreviewLayer? }
}

@MainActor
final class CaptureViewModel: NSObject, ObservableObject, CameraServiceDelegate {
    let camera = CameraService()
    @Published var focusScore: Double = 0
    @Published var glareRatio: Double = 0
    @Published var torchOn: Bool = false
    @Published var ready: Bool = false
    @Published var status: String = "Preparing…"
    @Published var navigatingToCrop = false
    private let capturedSubject = PassthroughSubject<UIImage, Never>()
    var captured: AnyPublisher<UIImage, Never> { capturedSubject.eraseToAnyPublisher() }

    override init() {
        super.init()
        camera.delegate = self
        // Reuse internal session for preview
        // CameraService manages its own session; for preview, expose it via KVC
    }

    func start() {
        camera.start()
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
                case .error(let err): self?.status = err.localizedDescription
                }
            }
            .store(in: &cancellables)
    }
    func stop() { camera.stop() }
    func toggleTorch() { torchOn.toggle(); camera.setTorch(enabled: torchOn) }
    func capture() { camera.capturePhoto() }

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
