import SwiftUI
import UIKit

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

@MainActor
final class AppState: ObservableObject {
    // Simple observable state used by unit tests and future features
    @Published var lastAction: String = ""
    @Published var capturedImage: UIImage?
    @Published var correctedImage: UIImage?
    @Published var rectangleCorners: [CGPoint] = []
    @Published var segmentation: SegmentationResult?
    @Published var objects: [CellObject] = []
    @Published var labeled: [CellObjectLabeled] = []
    @Published var pxPerMicron: Double?
    @Published var focusScore: Double = 0
    @Published var glareRatio: Double = 0
    @Published var samples: [Sample] = []
    @Published var debugImages: [String: UIImage] = [:]

    init() {
        do { try AppDatabase.shared.setup() } catch { Logger.log("DB setup failed: \(error)") }
        CrashReporter.shared.start()
    }
}

struct RootView: View {
    @AppStorage("consent.shown") private var consentShown: Bool = false
    @StateObject private var purchases = PurchaseManager.shared
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
        .tint(Theme.accent)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await purchases.loadProducts() }
        .sheet(isPresented: .constant(!consentShown)) {
            ConsentView(consentShown: $consentShown)
        }
    }
}
