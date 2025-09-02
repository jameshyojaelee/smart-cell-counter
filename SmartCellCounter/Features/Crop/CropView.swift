import SwiftUI

@MainActor
final class CropViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var corners: [CGPoint] = [] // TL,TR,BR,BL in image space
    @Published var lowResPreview: UIImage?

    func updateLowResPreview() {
        guard let img = image, corners.count == 4 else { return }
        let small = img.scaled(maxDim: 512)
        lowResPreview = ImagingPipeline.perspectiveCorrect(small, corners: corners.scaled(from: img.size, to: small.size))
    }
}

extension Array where Element == CGPoint {
    func scaled(from src: CGSize, to dst: CGSize) -> [CGPoint] {
        self.map { CGPoint(x: $0.x * (dst.width/src.width), y: $0.y * (dst.height/src.height)) }
    }
}

extension UIImage {
    func scaled(maxDim: Int) -> UIImage {
        let w = Int(size.width), h = Int(size.height)
        let s = max(1, max(w,h) / maxDim)
        let nw = w / s, nh = h / s
        let r = UIGraphicsImageRenderer(size: CGSize(width: nw, height: nh))
        return r.image { _ in self.draw(in: CGRect(x: 0, y: 0, width: nw, height: nh)) }
    }
}

struct CropView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CropViewModel()
    @State private var goToReview = false

    var body: some View {
        VStack(spacing: 8) {
            if let img = viewModel.image {
                ZStack {
                    if let low = viewModel.lowResPreview {
                        Image(uiImage: low)
                            .resizable()
                            .scaledToFit()
                            .opacity(0.4)
                    }
                    CornerEditorView(image: Binding(get: { img }, set: { viewModel.image = $0 }), corners: $viewModel.corners)
                        .onChange(of: viewModel.corners) { _ in viewModel.updateLowResPreview() }
                }
            } else {
                Text("No image. Go back to Capture.")
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Auto Detect") {
                    if let img = viewModel.image {
                        let det = ImagingPipeline.detectGrid(in: img)
                        if det.found { viewModel.corners = det.corners }
                        viewModel.updateLowResPreview()
                    }
                }
                Spacer()
                Button("Apply") {
                    guard let img = viewModel.image, viewModel.corners.count == 4 else { return }
                    let corrected = ImagingPipeline.perspectiveCorrect(img, corners: viewModel.corners)
                    appState.correctedImage = corrected
                    appState.rectangleCorners = viewModel.corners
                    goToReview = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .onAppear {
            if let img = appState.capturedImage { viewModel.image = img }
            if viewModel.corners.count != 4, let img = viewModel.image {
                viewModel.corners = [CGPoint(x: 0, y: 0), CGPoint(x: img.size.width, y: 0), CGPoint(x: img.size.width, y: img.size.height), CGPoint(x: 0, y: img.size.height)]
                viewModel.updateLowResPreview()
            }
        }
        .navigationTitle("Crop")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { NavigationLink(destination: ReviewView(), isActive: $goToReview) { EmptyView() } } }
    }
}
