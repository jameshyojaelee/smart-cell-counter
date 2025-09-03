import SwiftUI
import PhotosUI

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CaptureViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var goToCrop = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                CameraPreviewView(session: viewModel.camera.captureSession)
                    .onAppear { viewModel.start() }
                    .onDisappear { viewModel.stop() }
                    .overlay(GridGuides().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .edgesIgnoringSafeArea(.all)

                HStack(spacing: 8) {
                    StatusChip(title: "Focus", value: String(format: "%.2f", viewModel.focusScore))
                    StatusChip(title: "Glare", value: String(format: "%.2f", viewModel.glareRatio))
                    Spacer()
                    Toggle(isOn: $viewModel.torchOn) { Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.torchOn) { _ in viewModel.toggleTorch() }
                }
                .padding(8)
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Import", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .onChange(of: photoItem) { newItem in
                    guard let item = newItem else { return }
                    Task { @MainActor in
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            appState.capturedImage = img
                            goToCrop = true
                        }
                    }
                }

                Button(action: {
                    viewModel.capture()
                }) {
                    Label("Capture", systemImage: "camera.circle.fill").font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
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
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    var body: some View {
        Text("\(title): \(value)")
            .font(.caption)
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
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
