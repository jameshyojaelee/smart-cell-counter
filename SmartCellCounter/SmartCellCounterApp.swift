import SwiftUI

@main
struct SmartCellCounterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

final class AppState: ObservableObject {
    // Simple observable state used by unit tests and future features
    @Published var lastAction: String = ""
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { CaptureView() }
                .tabItem { Label("Capture", systemImage: "camera") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
            NavigationStack { ResultsView() }
                .tabItem { Label("Results", systemImage: "chart.bar.xaxis") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
