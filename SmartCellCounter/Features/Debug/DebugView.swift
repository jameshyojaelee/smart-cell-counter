import SwiftUI

struct DebugView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DebugViewModel()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(appState.debugImages.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 6) {
                        if let img = appState.debugImages[key] {
                            Image(uiImage: img).resizable().scaledToFit().frame(height: 120).cornerRadius(6)
                        }
                        Text(key).font(.caption)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()

            VStack(alignment: .leading, spacing: 8) {
                Text("Performance").font(.headline)
                // Placeholder; real timings can be stored into appState.debugImages or a separate store
                Text("Segmentation/Counting timings are displayed here when available.")
                    .font(.caption).foregroundColor(.secondary)
                NavigationLink("Run QA Fixtures", destination: QATestsView())
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Debug")
        .appBackground()
    }
}

final class DebugViewModel: ObservableObject {}
