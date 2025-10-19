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
    @Published var selectedLargeSquares: [Int] = [0, 2, 6, 8]

    init() {
        Task {
            do { try await AppDatabase.shared.setup() }
            catch { Logger.log("DB setup failed: \(error)") }
        }
    }
}

struct RootView: View {
    @AppStorage("consent.shown") private var consentShown: Bool = false
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showConsent = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            NavigationStack { CaptureView() }
                .tabItem { Label(L10n.App.captureTab, systemImage: "camera") }
            NavigationStack { HistoryView() }
                .tabItem { Label(L10n.App.historyTab, systemImage: "clock") }
            NavigationStack { ResultsView() }
                .tabItem { Label(L10n.App.resultsTab, systemImage: "chart.bar.xaxis") }
            NavigationStack { SettingsView() }
                .tabItem { Label(L10n.App.settingsTab, systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await purchases.loadProducts() }
        .sheet(isPresented: $showConsent) {
            ConsentView(consentShown: $consentShown)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                onboardingCompleted = true
                AnalyticsLogger.shared.log(event: "onboarding_completed")
                showOnboarding = false
                showConsent = !consentShown
            }
        }
        .onAppear {
            if !onboardingCompleted {
                showOnboarding = true
            } else {
                showConsent = !consentShown
            }
        }
    }
}
