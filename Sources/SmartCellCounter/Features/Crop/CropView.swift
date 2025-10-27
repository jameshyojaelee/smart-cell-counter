import SwiftUI

@MainActor
final class CropViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var selectionInImage: CGRect = .zero
}

struct CropView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CropViewModel()
    @State private var goToReview = false
    private let isUITestMock = ProcessInfo.processInfo.arguments.contains("-UITest.MockCapture")

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if let img = viewModel.image {
                ImageSelectionView(image: img, fixedAspect: nil) { imgRect in
                    viewModel.selectionInImage = imgRect
                }
                HStack(spacing: DS.Spacing.lg) {
                    Spacer()
                    Button(L10n.Selection.confirmButton) {
                        guard let img = viewModel.image else { return }
                        if let cropped = GeometryUtils.crop(image: img, to: viewModel.selectionInImage) {
                            appState.correctedImage = cropped
                        } else {
                            appState.correctedImage = img
                        }
                        goToReview = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(L10n.Selection.overlayHint)
                }
            } else {
                Text(L10n.Crop.noImage).foregroundColor(.secondary)
            }
        }
        .onAppear {
            if let img = appState.capturedImage { viewModel.image = img }
            if isUITestMock {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    autoConfirmMock()
                }
            }
        }
        .navigationTitle(L10n.Crop.navigationTitle)
        .modifier(CropNavigation(goToReview: $goToReview))
    }

    private func autoConfirmMock() {
        guard isUITestMock else { return }
        guard let img = viewModel.image else { return }
        appState.correctedImage = img
        goToReview = true
    }
}

// MARK: - Navigation modernization

private struct CropNavigation: ViewModifier {
    @Binding var goToReview: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .navigationDestination(isPresented: $goToReview) { ReviewView() }
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: ReviewView(), isActive: $goToReview) { EmptyView() }
                    }
                }
        }
    }
}
