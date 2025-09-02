import SwiftUI

struct DebugView: View {
    @StateObject private var viewModel = DebugViewModel()

    var body: some View {
        List {
            Section(header: Text("Logs")) {
                Text("No logs yet")
            }
        }
        .navigationTitle("Debug")
    }
}

final class DebugViewModel: ObservableObject {}
