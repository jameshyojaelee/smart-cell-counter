import SwiftUI

struct ConsentView: View {
    @Binding var consentShown: Bool
    @State private var personalizedAds = false
    @State private var crashReports = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Privacy & Consent")) {
                    Toggle("Personalized Ads", isOn: $personalizedAds)
                    Toggle("Crash Reports", isOn: $crashReports)
                    Text("You can change these anytime in Settings.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section {
                    Button("Continue") {
                        Settings.shared.personalizedAds = personalizedAds
                        // If user opted-in, request ATT (if available)
                        if personalizedAds { ConsentManager().requestTrackingIfNeeded() }
                        consentShown = true
                    }.buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Consent")
        }
    }
}

