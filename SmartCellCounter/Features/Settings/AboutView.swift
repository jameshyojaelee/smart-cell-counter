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
                Text("Smart Cell Counter").font(.title).bold()
                Text("Version: \(appVersion)").font(.subheadline).foregroundColor(.secondary)

                GroupBox("Important Notice") {
                    Text("Research use only. Not a medical device. This app is not intended for diagnosis or treatment and has not been evaluated or approved by regulatory authorities.")
                        .font(.subheadline)
                }

                GroupBox("Privacy") {
                    Text("All image processing occurs on-device. The app does not collect or transmit Personal Health Information (PHI). Camera and Photos access are used only for capturing and importing images at your direction.")
                        .font(.subheadline)
                }

                GroupBox("Third‑Party Software and Licenses") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GRDB.swift — MIT License").frame(maxWidth: .infinity, alignment: .leading)
                        Text("GoogleMobileAds (optional) — See Google’s Terms").frame(maxWidth: .infinity, alignment: .leading)
                        Text("PDFKit, Vision, Core Image, AVFoundation — Apple Frameworks")
                    }.font(.footnote)
                }

                GroupBox("Contact") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Support: https://www.smartcellcounter.com/support")
                        Text("Privacy Policy: https://www.smartcellcounter.com/privacy")
                        Text("Email: jameshyojaelee@gmail.com")
                    }.font(.footnote)
                }
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

