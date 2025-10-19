import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Settings.About.appName).font(.title).bold()
                Text(L10n.Settings.About.version(appVersion)).font(.subheadline).foregroundColor(.secondary)

                GroupBox(L10n.Settings.About.noticeTitle) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Settings.About.noticeDevelopment)
                            .font(.subheadline)
                        Text(L10n.Settings.About.noticeResearch)
                            .font(.subheadline)
                    }
                }

                GroupBox(L10n.Settings.About.privacyTitle) {
                    Text(L10n.Settings.About.privacyBody)
                        .font(.subheadline)
                }

                GroupBox(L10n.Settings.About.licensesTitle) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.Settings.About.licenseGRDB).frame(maxWidth: .infinity, alignment: .leading)
                        Text(L10n.Settings.About.licenseGMA).frame(maxWidth: .infinity, alignment: .leading)
                        Text(L10n.Settings.About.licenseApple)
                    }.font(.footnote)
                }

                GroupBox(L10n.Settings.About.contactTitle) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.Settings.About.contactSupport)
                        Text(L10n.Settings.About.contactPrivacy)
                        Text(L10n.Settings.About.contactEmail)
                    }.font(.footnote)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.Settings.About.screenTitle)
    }
}
