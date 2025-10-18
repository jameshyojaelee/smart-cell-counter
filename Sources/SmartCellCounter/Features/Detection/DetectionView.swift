import SwiftUI

struct DetectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showOverlays = true
    @State private var overlayKind = "Candidates"

    var body: some View {
        VStack {
            if let img = appState.correctedImage ?? appState.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .overlay(DebugOverlayView(debugImages: appState.debugImages, kind: overlayKind).opacity(showOverlays ? 1 : 0))
                HStack {
                    Toggle("Overlays", isOn: $showOverlays).toggleStyle(.switch)
                    Picker("Kind", selection: $overlayKind) {
                        Text("Candidates").tag("Candidates")
                        Text("Blue Mask").tag("Blue Mask")
                        Text("Grid Mask").tag("Grid Mask")
                        Text("Illumination").tag("Illumination")
                    }.pickerStyle(.segmented)
                }.padding()
            } else {
                Text("No image").foregroundColor(.secondary)
            }
        }
        .navigationTitle("Detection")
    }
}


