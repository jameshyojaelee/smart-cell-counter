import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var settings = Settings.shared

    var body: some View {
        List {
            Section(header: Text("General")) {
                Picker("Chamber", selection: $settings.chamberType) {
                    ForEach(["Neubauer Improved", "Neubauer", "Burker"], id: \.self) { Text($0) }
                }
                Picker("Stain", selection: $settings.stainType) {
                    ForEach(["Trypan Blue", "PI", "None"], id: \.self) { Text($0) }
                }
                HStack {
                    Text("Default Dilution")
                    Spacer()
                    Stepper(String(format: "%.1fx", settings.defaultDilution), value: $settings.defaultDilution, in: 0.1...100, step: 0.1)
                }
            }

            Section(header: Text("Segmentation")) {
                Picker("Threshold", selection: $settings.thresholdMethod) {
                    Text("Adaptive").tag(ThresholdMethod.adaptive)
                    Text("Otsu").tag(ThresholdMethod.otsu)
                }
                Stepper("Block Size: \(settings.blockSize)", value: $settings.blockSize, in: 31...101, step: 2)
                Stepper("C: \(settings.C)", value: $settings.C, in: -10...10, step: 1)
                Toggle("Use Watershed", isOn: $settings.useWatershed)
                if PurchaseManager.shared.isPro {
                    Toggle("ML Refine (Pro: Always On)", isOn: .constant(true)).disabled(true)
                } else {
                    Toggle("Enable ML Refine", isOn: $settings.enableMLRefine)
                }
            }

            Section(header: Text("Area Filters (µm²)")) {
                Stepper("Min: \(Int(settings.minAreaUm2))", value: $settings.minAreaUm2, in: 10...1000, step: 10)
                Stepper("Max: \(Int(settings.maxAreaUm2))", value: $settings.maxAreaUm2, in: 500...20000, step: 50)
            }

            Section(header: Text("Privacy")) {
                Toggle("Personalized Ads", isOn: $settings.personalizedAds)
            }

            Section(header: Text("More")) {
                NavigationLink("Paywall", destination: PaywallView())
                NavigationLink("Help", destination: HelpView())
                NavigationLink("Debug", destination: DebugView())
                NavigationLink("About", destination: AboutView())
            }
        }
        .navigationTitle("Settings")
        .appBackground()
    }
}

final class SettingsViewModel: ObservableObject {}
