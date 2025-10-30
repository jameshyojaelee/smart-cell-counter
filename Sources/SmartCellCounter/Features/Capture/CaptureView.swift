import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CaptureViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var goToCrop = false
    @State private var showGrid = true
    @State private var focusIndicator: FocusIndicator?
    @State private var mockConfigured = false

    private let isUITestMock = ProcessInfo.processInfo.arguments.contains("-UITest.MockCapture")

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    ZStack {
                        previewLayer(size: geo.size)

                        if showGrid {
                            GridGuides().stroke(Theme.border.opacity(0.4), lineWidth: 1)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        TargetRect()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)

                        if let indicator = focusIndicator {
                            FocusIndicatorView()
                                .position(clamp(indicator.point, in: geo.size))
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)

                    HStack(alignment: .top) {
                        CaptureHUDView(
                            statusText: viewModel.status,
                            isReady: viewModel.ready,
                            focusScore: viewModel.focusScore,
                            glareRatio: viewModel.glareRatio,
                            torchOn: Binding(
                                get: { viewModel.torchOn },
                                set: { viewModel.setTorch(enabled: $0) }
                            ),
                            permissionDenied: viewModel.permissionDenied,
                            onSettingsTap: openSettings
                        )

                        Button(action: { showGrid.toggle() }) {
                            Image(systemName: showGrid ? "grid" : "grid.circle")
                                .font(.headline)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(L10n.Capture.gridToggleLabel(isVisible: showGrid))
                        .accessibilityHint(L10n.Capture.gridToggleHint)
                        .accessibilityValue(L10n.Capture.gridToggleValue(isVisible: showGrid))
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
            }

            controlBar
                .accessibilityElement(children: .contain)
        }
        .navigationTitle(L10n.Capture.navigationTitle)
        .modifier(CaptureNavigation(goToCrop: $goToCrop))
        .onAppear {
            if isUITestMock {
                configureMockCapture()
            } else {
                viewModel.onAppear()
            }
        }
        .onDisappear {
            if !isUITestMock {
                viewModel.onDisappear()
            }
        }
        .onChange(of: scenePhase) { phase in
            if !isUITestMock {
                viewModel.handleScenePhase(phase)
            }
        }
        .onReceive(viewModel.$focusScore) { appState.focusScore = $0 }
        .onReceive(viewModel.$glareRatio) { appState.glareRatio = $0 }
        .onReceive(viewModel.captured) { image in
            appState.capturedImage = image
            goToCrop = true
        }
        .appBackground()
    }

    @ViewBuilder
    private func previewLayer(size: CGSize) -> some View {
        if isUITestMock {
            MockCapturePreview()
                .accessibilityIdentifier("mockCapturePreview")
        } else if viewModel.previewEnabled {
            CameraPreviewView(session: viewModel.captureSession) { layerPoint, devicePoint in
                handleFocusTap(layerPoint: layerPoint, devicePoint: devicePoint, size: size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Capture.cameraPreviewLabel)
            .accessibilityHint(L10n.Capture.cameraPreviewHint)
            .transition(.opacity)
        } else {
            ZStack {
                Rectangle().fill(Theme.surface)
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(Theme.textSecondary)
                    Text(viewModel.permissionDenied ? L10n.Capture.permissionDisabledTitle : viewModel.status)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.Capture.permissionDisabledTitle)
            .accessibilityValue(viewModel.status)
        }
    }

    private var controlBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 28) {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                }
                .accessibilityLabel(L10n.Capture.importLabel)
                .accessibilityHint(L10n.Capture.importHint)
                .accessibilityAddTraits(.isButton)
                .onChange(of: photoItem) { newItem in
                    guard let item = newItem else { return }
                    Task { @MainActor in
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            appState.capturedImage = img
                            goToCrop = true
                        }
                    }
                }
                .accessibilitySortPriority(1)

                Button(action: shutterTapped) {
                    ZStack {
                        Circle().fill(Theme.textPrimary).frame(width: 72, height: 72)
                        Circle().stroke(Theme.background, lineWidth: 4).frame(width: 84, height: 84)
                    }
                }
                .accessibilityLabel(L10n.Capture.shutterLabel)
                .accessibilityHint(L10n.Capture.shutterHint(isReady: viewModel.ready))
                .accessibilityValue(L10n.Capture.shutterValue(isReady: viewModel.ready))
                .disabled(!viewModel.ready)
                .accessibilitySortPriority(3)

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "slider.horizontal.3").font(.title2)
                }
                .accessibilityLabel(L10n.Capture.settingsLabel)
                .accessibilityHint(L10n.Capture.settingsHint)
                .accessibilitySortPriority(2)
            }
            .padding(.bottom, 10)
        }
    }

    private func shutterTapped() {
        if isUITestMock {
            if appState.capturedImage == nil {
                appState.capturedImage = MockCaptureData.placeholderImage
            }
            goToCrop = true
        } else {
            guard viewModel.ready else { return }
            Haptics.impact(.medium)
            viewModel.capture()
        }
    }

    private func handleFocusTap(layerPoint: CGPoint, devicePoint: CGPoint, size: CGSize) {
        viewModel.focus(at: devicePoint)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            focusIndicator = FocusIndicator(point: clamp(layerPoint, in: size))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) {
                focusIndicator = nil
            }
        }
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let padding: CGFloat = 40
        let x = min(max(point.x, padding), size.width - padding)
        let y = min(max(point.y, padding), size.height - padding)
        return CGPoint(x: x, y: y)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func configureMockCapture() {
        guard !mockConfigured else { return }
        mockConfigured = true

        viewModel.permissionDenied = false
        viewModel.previewEnabled = false
        viewModel.status = L10n.Capture.Status.ready
        viewModel.ready = true

        if appState.capturedImage == nil {
            let placeholder = MockCaptureData.placeholderImage
            appState.capturedImage = placeholder
            appState.correctedImage = placeholder
            appState.segmentation = SegmentationResult(width: 32,
                                                       height: 32,
                                                       mask: MockCaptureData.segmentationMask,
                                                       downscaleFactor: 1,
                                                       polarityInverted: false,
                                                       usedStrategy: .classical,
                                                       originalSize: placeholder.size)

            appState.objects = MockCaptureData.objects
            appState.labeled = MockCaptureData.labeled
            appState.debugImages["mock_preview"] = placeholder
            appState.pxPerMicron = 1.0
        }
    }
}

// MARK: - Navigation modernization

private struct CaptureNavigation: ViewModifier {
    @Binding var goToCrop: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .navigationDestination(isPresented: $goToCrop) { CropView() }
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CropView(), isActive: $goToCrop) { EmptyView() }
                    }
                }
        }
    }
}

private struct MockCapturePreview: View {
    var body: some View {
        ZStack {
            Image(uiImage: MockCaptureData.placeholderImage)
                .resizable()
                .scaledToFit()
            VStack(spacing: 8) {
                Text("UITest Mock Preview")
                    .font(.headline)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("No camera required")
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundColor(.white)
        }
    }
}

private enum MockCaptureData {
    static let placeholderSize = CGSize(width: 512, height: 512)

    static let placeholderImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: placeholderSize)
        return renderer.image { ctx in
            let bounds = CGRect(origin: .zero, size: placeholderSize)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [UIColor.systemTeal.cgColor, UIColor.systemIndigo.cgColor] as CFArray,
                                         locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [])
            } else {
                ctx.cgContext.setFillColor(UIColor.systemTeal.cgColor)
                ctx.cgContext.fill(bounds)
            }

            ctx.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 120, y: 140, width: 120, height: 120))
            ctx.cgContext.fillEllipse(in: CGRect(x: 280, y: 220, width: 90, height: 90))

            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.stroke(CGRect(x: 90, y: 90, width: 332, height: 332))
            ctx.cgContext.stroke(CGRect(x: 160, y: 160, width: 200, height: 200))
        }
    }()

    static let segmentationMask: [Bool] = (0 ..< 1024).map { index in index % 21 == 0 }

    static let objects: [CellObject] = {
        let cell1 = CellObject(id: 0,
                               pixelCount: 150,
                               areaPx: 150,
                               perimeterPx: 44,
                               circularity: 0.85,
                               solidity: 0.92,
                               centroid: CGPoint(x: 220, y: 240),
                               bbox: CGRect(x: 190, y: 210, width: 60, height: 60))
        let cell2 = CellObject(id: 1,
                               pixelCount: 120,
                               areaPx: 120,
                               perimeterPx: 40,
                               circularity: 0.80,
                               solidity: 0.90,
                               centroid: CGPoint(x: 310, y: 180),
                               bbox: CGRect(x: 285, y: 155, width: 50, height: 50))
        return [cell1, cell2]
    }()

    static let labeled: [CellObjectLabeled] = {
        let live = CellObjectLabeled(id: 0,
                                     base: objects[0],
                                     color: ColorSampleStats(hue: 120, saturation: 0.7, value: 0.8, L: 65, a: -5, b: 15),
                                     label: "live",
                                     confidence: 0.94)
        let dead = CellObjectLabeled(id: 1,
                                     base: objects[1],
                                     color: ColorSampleStats(hue: 220, saturation: 0.5, value: 0.6, L: 55, a: 10, b: -5),
                                     label: "dead",
                                     confidence: 0.82)
        return [live, dead]
    }()
}

private struct GridGuides: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 3x3 grid overlay (approximate guide)
        for i in 1 ..< 3 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

private struct TargetRect: View {
    var body: some View {
        GeometryReader { geo in
            let rectW = geo.size.width * 0.6
            let rectH = geo.size.height * 0.4
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .frame(width: rectW, height: rectH)
                    .position(x: centerX, y: centerY)

                Text(L10n.Capture.framingHint)
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface.opacity(0.7))
                    .foregroundColor(Theme.textPrimary)
                    .clipShape(Capsule())
                    .position(x: centerX, y: centerY + rectH / 2 + 18)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct FocusIndicator: Identifiable {
    let id = UUID()
    let point: CGPoint
}

private struct FocusIndicatorView: View {
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(Theme.accent, lineWidth: 2)
            .frame(width: animate ? 100 : 70, height: animate ? 100 : 70)
            .opacity(animate ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    animate = true
                }
            }
    }
}
