import SwiftUI
import PhotosUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = CaptureViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var goToCrop = false
    @State private var showGrid = true
    @State private var focusIndicator: FocusIndicator?

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
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: scenePhase) { viewModel.handleScenePhase($0) }
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
        if viewModel.previewEnabled {
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
        guard viewModel.ready else { return }
        Haptics.impact(.medium)
        viewModel.capture()
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
                .background(
                    NavigationLink(destination: CropView(), isActive: $goToCrop) { EmptyView() }
                )
        }
    }
}

private struct GridGuides: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 3x3 grid overlay (approximate guide)
        for i in 1..<3 {
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
                    .strokeBorder(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6,6]))
                    .frame(width: rectW, height: rectH)
                    .position(x: centerX, y: centerY)

                Text(L10n.Capture.framingHint)
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface.opacity(0.7))
                    .foregroundColor(Theme.textPrimary)
                    .clipShape(Capsule())
                    .position(x: centerX, y: centerY + rectH/2 + 18)
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
