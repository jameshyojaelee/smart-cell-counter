import SwiftUI
import PhotosUI

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CaptureViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var goToCrop = false
    @State private var showGrid = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                CameraPreviewView(session: viewModel.camera.captureSession)
                    .onAppear { viewModel.start() }
                    .onDisappear { viewModel.stop() }
                    .overlay(
                        Group {
                            if showGrid { GridGuides().stroke(Theme.border.opacity(0.4), lineWidth: 1) }
                            TargetRect()
                        }
                    )
                    .edgesIgnoringSafeArea(.all)

                HStack(spacing: 8) {
                    Chip("Focus: " + String(format: "%.2f", viewModel.focusScore), systemImage: "viewfinder", color: Theme.surface.opacity(0.6))
                    Chip("Glare: " + String(format: "%.2f", viewModel.glareRatio), systemImage: "sun.max", color: Theme.surface.opacity(0.6))
                    Spacer()
                    Button(action: { showGrid.toggle() }) {
                        Image(systemName: showGrid ? "grid" : "grid.circle")
                    }
                    .padding(8)
                    .background(Theme.surface.opacity(0.6))
                    .clipShape(Capsule())
                    Toggle(isOn: $viewModel.torchOn) { Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.torchOn) { _ in viewModel.toggleTorch() }
                        .accessibilityLabel("Toggle Flashlight")
                }
                .padding(8)
            }

            VStack(spacing: 6) {
                Text(viewModel.status).font(.caption).foregroundColor(Theme.textSecondary)
                if viewModel.permissionDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                HStack(spacing: 28) {
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.on.rectangle").font(.title2)
                    }
                    .onChange(of: photoItem) { newItem in
                        guard let item = newItem else { return }
                        Task { @MainActor in
                            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                                appState.capturedImage = img
                                goToCrop = true
                            }
                        }
                    }
                    .accessibilityLabel("Import from Photos")

                    Button(action: {
                        guard viewModel.ready else { return }
                        Haptics.impact(.medium)
                        viewModel.capture()
                    }) {
                        ZStack {
                            Circle().fill(Theme.textPrimary).frame(width: 72, height: 72)
                            Circle().stroke(Theme.background, lineWidth: 4).frame(width: 84, height: 84)
                        }
                    }
                    .accessibilityLabel("Shutter")
                    .disabled(!viewModel.ready)

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "slider.horizontal.3").font(.title2)
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.bottom, 10)
            }
        }
        .navigationTitle("Capture")
        .background(
            NavigationLink(destination: CropView(), isActive: $goToCrop) { EmptyView() }
        )
        .onReceive(viewModel.$focusScore) { appState.focusScore = $0 }
        .onReceive(viewModel.$glareRatio) { appState.glareRatio = $0 }
        .onReceive(viewModel.captured) { image in
            appState.capturedImage = image
            goToCrop = true
        }
        .appBackground()
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
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6,6]))
                .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.4)
                .position(x: geo.size.width/2, y: geo.size.height/2.6)
                .accessibilityHidden(true)
        }
    }
}
