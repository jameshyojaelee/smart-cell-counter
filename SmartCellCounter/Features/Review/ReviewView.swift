import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Review").font(.largeTitle)
            Button("Mark Reviewed") {
                appState.lastAction = "review"
                Logger.log("Action set: review")
            }
            NavigationLink("Go to Results", destination: ResultsView())
        }
        .padding()
        .navigationTitle("Review")
    }
}

final class ReviewViewModel: ObservableObject {}
