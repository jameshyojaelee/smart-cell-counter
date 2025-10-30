import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

@main
struct SmartCellCounterApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
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
            do { try await AppDatabase.shared.setup() } catch { Logger.log("DB setup failed: \(error)") }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager // Get AuthManager from environment

    @AppStorage("consent.shown") private var consentShown: Bool = false
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showConsent = false
    @State private var showOnboarding = false

    var body: some View {
        // Use a ZStack to conditionally show content
        ZStack {
            if authManager.isAuthenticated && onboardingCompleted {
                // USER IS LOGGED IN AND ONBOARDED
                // Show the main app
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

            } else {
                // USER IS NOT LOGGED IN OR NOT ONBOARDED
                // Show a simple background while modal sheets are figured out
                Theme.background.ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                onboardingCompleted = true
                AnalyticsLogger.shared.log(event: "onboarding_completed")
                showOnboarding = false

                // If not logged in, show login view right after onboarding
                // If already logged in (e.g., from a previous session), this will be false
                if !authManager.isAuthenticated {
                    // This space is intentionally left blank to allow
                    // the main ZStack to present the LoginView
                } else {
                    // Onboarding is done and user is logged in, show consent if needed
                    showConsent = !consentShown
                }
            }
        }
        .fullScreenCover(isPresented: .constant(!authManager.isAuthenticated && onboardingCompleted)) {
            // NEW: Show LoginView if onboarding is done but user is NOT authenticated
            LoginView()
        }
        .onAppear {
            if !onboardingCompleted {
                showOnboarding = true
            } else if authManager.isAuthenticated {
                // Onboarding is done, user is logged in
                showConsent = !consentShown
            }
            // If !onboardingCompleted, the onboarding view will show.
            // If onboardingCompleted and !isAuthenticated, the LoginView .fullScreenCover will show.
        }
    }
}
