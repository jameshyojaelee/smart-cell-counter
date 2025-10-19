import SwiftUI

struct ConsentView: View {
    @Binding var consentShown: Bool
    @State private var personalizedAds = Settings.shared.personalizedAds
    @State private var crashReports = Settings.shared.crashReportingEnabled
    @State private var analytics = Settings.shared.analyticsEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.Consent.sectionTitle)) {
                    Toggle(L10n.Consent.personalizedAds, isOn: $personalizedAds)
                    Toggle(L10n.Consent.crashReporting, isOn: $crashReports)
                    Toggle(L10n.Consent.analytics, isOn: $analytics)
                    Text(L10n.Consent.reminder)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Section {
                    Button(L10n.Consent.continueButton) {
                        Settings.shared.personalizedAds = personalizedAds
                        Settings.shared.crashReportingEnabled = crashReports
                        Settings.shared.analyticsEnabled = analytics
                        // If user opted-in, request ATT (if available)
                        if personalizedAds { ConsentManager().requestTrackingIfNeeded() }
                        AnalyticsLogger.shared.log(event: "consent_completed", metadata: ["ads": String(personalizedAds), "crash": String(crashReports), "analytics": String(analytics)])
                        consentShown = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(L10n.Consent.continueHint)
                }
            }
            .navigationTitle(L10n.Consent.navigationTitle)
        }
        .onAppear {
            personalizedAds = Settings.shared.personalizedAds
            crashReports = Settings.shared.crashReportingEnabled
            analytics = Settings.shared.analyticsEnabled
        }
    }
}
