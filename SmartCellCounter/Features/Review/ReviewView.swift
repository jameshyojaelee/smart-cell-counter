import SwiftUI

struct ReviewView: View {
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Review").font(.largeTitle)
            NavigationLink("Go to Results", destination: ResultsView())
        }
        .padding()
        .navigationTitle("Review")
    }
}

final class ReviewViewModel: ObservableObject {}
