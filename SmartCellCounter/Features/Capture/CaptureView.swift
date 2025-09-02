import SwiftUI

struct CaptureView: View {
    @StateObject private var viewModel = CaptureViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Capture").font(.largeTitle)
            NavigationLink("Go to Crop", destination: CropView())
        }
        .padding()
        .navigationTitle("Capture")
    }
}

final class CaptureViewModel: ObservableObject {}
