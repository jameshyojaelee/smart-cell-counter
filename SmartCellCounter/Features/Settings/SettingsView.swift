import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            Section(header: Text("General")) {
                NavigationLink("Paywall", destination: PaywallView())
                NavigationLink("Help", destination: HelpView())
                NavigationLink("Debug", destination: DebugView())
            }
        }
        .navigationTitle("Settings")
    }
}

final class SettingsViewModel: ObservableObject {}
