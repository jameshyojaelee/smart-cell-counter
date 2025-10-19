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
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .cornerRadius(6)
                                .accessibilityHidden(true)
                        }
                        Text(key).font(.caption)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(key)
                }
            }
            .padding()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Debug.performanceTitle).font(.headline)
                Text(L10n.Debug.timingsDescription)
                    .font(.caption).foregroundColor(.secondary)
                NavigationLink(L10n.Debug.qaFixtures, destination: QATestsView())
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle(L10n.Debug.navigationTitle)
        .appBackground()
    }
}

final class DebugViewModel: ObservableObject {}
