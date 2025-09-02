import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel = ResultsViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Results").font(.largeTitle)
        }
        .padding()
        .navigationTitle("Results")
    }
}

final class ResultsViewModel: ObservableObject {}
