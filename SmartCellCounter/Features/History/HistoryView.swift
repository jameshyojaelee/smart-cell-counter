import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("History").font(.largeTitle)
        }
        .padding()
        .navigationTitle("History")
    }
}

final class HistoryViewModel: ObservableObject {}
