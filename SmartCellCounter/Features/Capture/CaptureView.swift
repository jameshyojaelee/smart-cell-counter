import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CaptureViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Capture").font(.largeTitle)
            Button("Simulate Capture Action") {
                appState.lastAction = "capture"
                Logger.log("Action set: capture")
            }
            NavigationLink("Go to Crop", destination: CropView())
        }
        .padding()
        .navigationTitle("Capture")
    }
}

final class CaptureViewModel: ObservableObject {}
