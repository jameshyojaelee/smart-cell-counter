import SwiftUI
import Combine
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onFocusTap: ((CGPoint, CGPoint) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.previewLayer = layer
        context.coordinator.onFocusTap = onFocusTap
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = context.coordinator.previewLayer {
            layer.frame = uiView.bounds
            if let conn = layer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }
        context.coordinator.onFocusTap = onFocusTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var onFocusTap: ((CGPoint, CGPoint) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard
                let view = gesture.view,
                let layer = previewLayer,
                let onFocusTap
            else { return }
            let layerPoint = gesture.location(in: view)
            let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onFocusTap(layerPoint, devicePoint)
        }
    }
}

@MainActor
final class CaptureViewModel: NSObject, ObservableObject, CameraServiceDelegate {
    let camera: CameraServicing
    @Published var focusScore: Double = 0
    @Published var glareRatio: Double = 0
    @Published var torchOn: Bool = false
    @Published var ready: Bool = false
    @Published var status: String = L10n.Capture.Status.preparing
    @Published var permissionDenied: Bool = false
    @Published var previewEnabled: Bool = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus

    private let capturedSubject = PassthroughSubject<UIImage, Never>()
    var captured: AnyPublisher<UIImage, Never> { capturedSubject.eraseToAnyPublisher() }

    private var cancellables: Set<AnyCancellable> = []
    private var subscriptionsConfigured = false
    private var isSessionRunning = false

    override init() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        self.camera = CameraService()
        self.authorizationStatus = status
        self.permissionDenied = (status == .denied || status == .restricted)
        self.previewEnabled = status == .authorized
        super.init()
        camera.delegate = self
    }

    init(service: CameraServicing) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        self.camera = service
        self.authorizationStatus = status
        self.permissionDenied = (status == .denied || status == .restricted)
        self.previewEnabled = status == .authorized
        super.init()
        camera.delegate = self
    }

    // MARK: - Lifecycle
    func onAppear() {
        refreshAuthorizationStatus()
        switch authorizationStatus {
        case .authorized:
            start()
        case .notDetermined:
            status = L10n.Capture.Status.requesting
            requestAuthorization()
        case .denied, .restricted:
            permissionDenied = true
            previewEnabled = false
            status = L10n.Capture.Status.denied
        @unknown default:
            status = L10n.Capture.Status.unavailable
        }
    }

    func onDisappear() {
        stop()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if authorizationStatus == .authorized {
                start()
            }
        case .inactive, .background:
            stop()
        @unknown default:
            break
        }
    }

    // MARK: - Camera control
    func start() {
        guard !permissionDenied else {
            status = L10n.Capture.Status.denied
            previewEnabled = false
            return
        }
        configureSubscriptionsIfNeeded()
        guard !isSessionRunning else { return }
        camera.start()
        isSessionRunning = true
    }

    func stop() {
        guard isSessionRunning else { return }
        camera.stop()
        isSessionRunning = false
        ready = false
        previewEnabled = false
    }

    func capture() {
        guard ready else { return }
        camera.capturePhoto()
    }

    func setTorch(enabled: Bool) {
        torchOn = enabled
        camera.setTorch(enabled: enabled)
    }

    func focus(at devicePoint: CGPoint) {
        guard !permissionDenied else { return }
        camera.setFocusExposure(point: devicePoint)
        status = L10n.Capture.Status.focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.ready && !self.permissionDenied {
                self.status = L10n.Capture.Status.ready
            }
        }
    }

    var captureSession: AVCaptureSession { camera.captureSession }

    // MARK: - CameraServiceDelegate
    func cameraService(_ service: CameraService, didUpdateFocusScore score: Double, glareRatio: Double) {
        focusScore = score
        self.glareRatio = glareRatio
    }

    func cameraService(_ service: CameraService, didCapture image: UIImage) {
        status = L10n.Capture.Status.saving
        capturedSubject.send(image)
    }

    // MARK: - Private helpers
    private func configureSubscriptionsIfNeeded() {
        guard !subscriptionsConfigured else { return }
        subscriptionsConfigured = true

        camera.readinessPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard let self else { return }
                self.ready = isReady
                if isReady {
                    self.previewEnabled = true
                    self.status = L10n.Capture.Status.ready
                } else if !self.permissionDenied {
                    self.status = L10n.Capture.Status.preparing
                }
            }
            .store(in: &cancellables)

        camera.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .idle:
                    self.status = L10n.Capture.Status.idle
                    self.ready = false
                case .preparing:
                    self.status = L10n.Capture.Status.preparing
                case .ready:
                    self.status = L10n.Capture.Status.ready
                    self.ready = true
                    self.permissionDenied = false
                    self.previewEnabled = true
                case .capturing:
                    self.status = L10n.Capture.Status.capturing
                case .saving:
                    self.status = L10n.Capture.Status.saving
                case .error(let error):
                    self.ready = false
                    self.status = error.errorDescription ?? L10n.Capture.Status.genericError
                    if case .permissionDenied = error {
                        self.permissionDenied = true
                        self.previewEnabled = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func refreshAuthorizationStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        permissionDenied = (status == .denied || status == .restricted)
        if status != .authorized {
            previewEnabled = false
        }
    }

    private func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                let status: AVAuthorizationStatus = granted ? .authorized : .denied
                self.authorizationStatus = status
                self.permissionDenied = !granted
                self.previewEnabled = granted
                if granted {
                    self.start()
                } else {
                    self.status = L10n.Capture.Status.denied
                }
            }
        }
    }
}
