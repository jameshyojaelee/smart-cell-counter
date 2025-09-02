import SwiftUI

struct HelpView: View {
    @StateObject private var viewModel = HelpViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Help").font(.largeTitle)
                Text("Instructions and FAQs coming soon.")
            }
            .padding()
        }
        .navigationTitle("Help")
    }
}

final class HelpViewModel: ObservableObject {}
