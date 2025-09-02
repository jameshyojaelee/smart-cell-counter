import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ResultsViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Results").font(.largeTitle)
            Text("Last Action: \(appState.lastAction)")
        }
        .padding()
        .navigationTitle("Results")
    }
}

final class ResultsViewModel: ObservableObject {}
