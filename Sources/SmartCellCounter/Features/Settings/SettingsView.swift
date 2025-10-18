import SwiftUI

struct SettingsView: View {
    @StateObject private var store = SettingsStore.shared
    @State private var validationMessage: String = ""

    var body: some View {
        List {
            Section(header: Text("General")) {
                NumericField("Dilution", value: $store.dilutionFactor, range: 0.1...100, step: 0.1) { msg in validationMessage = msg }
                if !validationMessage.isEmpty { Text(validationMessage).font(.caption).foregroundColor(.orange) }
            }

            Section(header: Text("Detection Ranges (µm²)", comment: "Area filters in square microns")) {
                NumericField("Area Min", value: $store.areaMinUm2, range: 1...1_000_000, step: 10) { msg in validationMessage = msg }
                NumericField("Area Max", value: $store.areaMaxUm2, range: 1...1_000_000, step: 50) { msg in validationMessage = msg }
            }

            Section(header: Text("Cell Size (µm)")) {
                NumericField("Min Diameter", value: $store.minCellDiameterUm, range: 1...200, step: 0.5) { msg in validationMessage = msg }
                NumericField("Max Diameter", value: $store.maxCellDiameterUm, range: 1...200, step: 0.5) { msg in validationMessage = msg }
            }

            Section(header: Text("Segmentation")) {
                Picker("Threshold", selection: $store.thresholdMethod) {
                    Text("Adaptive").tag(ThresholdMethod.adaptive)
                    Text("Otsu").tag(ThresholdMethod.otsu)
                }
                Stepper("Block Size: \(store.blockSize)", value: $store.blockSize, in: 31...101, step: 2)
                Stepper("C: \(store.thresholdC)", value: $store.thresholdC, in: -10...10, step: 1)
            }

            Section(header: Text("Blue Classification (HSV)")) {
                NumericField("Hue Min", value: $store.blueHueMin, range: 0...360, step: 1) { msg in validationMessage = msg }
                NumericField("Hue Max", value: $store.blueHueMax, range: 0...360, step: 1) { msg in validationMessage = msg }
                NumericField("Min Saturation", value: $store.minBlueSaturation, range: 0...1, step: 0.05) { msg in validationMessage = msg }
            }

            Section(header: Text("Detection Thresholds")) {
                NumericField("Blob Score Threshold", value: $store.blobScoreThreshold, range: 0...1, step: 0.05) { msg in validationMessage = msg }
                NumericField("NMS IoU", value: $store.nmsIoU, range: 0...1, step: 0.05) { msg in validationMessage = msg }
                NumericField("Min Focus (Laplacian)", value: $store.focusMinLaplacian, range: 0...10000, step: 10) { msg in validationMessage = msg }
                Toggle("Grid Suppression", isOn: $store.enableGridSuppression)
            }

            Section {
                Button("Reset to Defaults") { store.reset(); validationMessage = "" }
                    .foregroundColor(.red)
            }

            Section(header: Text("More")) {
                NavigationLink("Help", destination: HelpView())
                NavigationLink("Debug", destination: DebugView())
                NavigationLink("About", destination: AboutView())
            }
        }
        .navigationTitle("Settings")
        .appBackground()
    }
}
